function gadget:GetInfo()
	return {
		name      = "Asset Shader (SB)",
		desc      = "Normal-mapped GGX shader for generated features, driven by the Asset shader panel.",
		author    = "gajop",
		date      = "2026",
		license   = "MIT OR Apache-2.0",
		layer     = 0,
		enabled   = true,
	}
end

local MESSAGE_PREFIX = "springboard|native|"
local SYNC_ACTION = "sbAssetShaderParams"

-- The panel's message arrives as `RecvLuaMsg`, which the engine only delivers to
-- the *synced* handle -- but the shader, its uniforms and the material bindings
-- are all unsynced. So the synced half exists purely to forward the envelope
-- across; without it the params updated a copy of the table nothing renders from.
if gadgetHandler:IsSyncedCode() then
	function gadget:RecvLuaMsg(msg)
		if msg:sub(1, #MESSAGE_PREFIX) == MESSAGE_PREFIX then
			SendToUnsynced(SYNC_ACTION, msg)
		end
	end

	return
end

local NORMAL_TEXUNIT = 2
local MATERIAL_TEXUNIT = 3
local DETAIL_TEXUNIT = 4
local SHADOW_TEXUNIT = 5
local DETAIL_COLOUR_TEXUNIT = 6
local DETAIL_DISTRIBUTION_TEXUNIT = 7
local DETAIL_DIRT_TEXUNIT = 8

local params = {
	enabled = true,
	debugView = 0,
	detailTileFine = 2.5,
	detailTileCoarse = 9.0,
	-- Calibrated, not chosen: see the note beside the panel's default in
	-- `asset_shader/ui/model.rs`. Kept in step with it, since this is what applies
	-- before the panel has said anything.
	detailStrength = 4.0,
	detailPitDensity = 0.30,
	detailPitDepth = 2.0,
	detailPitRoughness = 0.22,
	detailPitColourStrength = {3.75, 3.30, 4.10},
	detailDirtNormalStrength = 1.20,
	detailDirtRoughness = 0.90,
	detailDirtAlbedoStrength = 0.92,
	roughnessBias = 0.0,
	shadowDensity = 0.7,
	shadowBias = 1.5,
	ambientScale = 1.0,
}

local shader
local featureMaps = {}
local applied = {}
local uniforms = {}

local vertexShader = [[
#version 120

varying vec3 viewNormal;
varying vec3 viewTangent;
varying vec3 viewBitangent;
varying vec2 texCoord;
varying vec3 objectPos;
varying vec3 objectNormal;
varying vec3 viewPos;

void main()
{
	gl_Position = gl_ModelViewProjectionMatrix * gl_Vertex;

	viewNormal    = gl_NormalMatrix * gl_Normal;
	// Tangent and bitangent ride on legacy texcoord units 5 and 6.
	viewTangent   = gl_NormalMatrix * gl_MultiTexCoord5.xyz;
	viewBitangent = gl_NormalMatrix * gl_MultiTexCoord6.xyz;

	texCoord     = gl_MultiTexCoord0.st;
	objectPos    = gl_Vertex.xyz;
	objectNormal = gl_Normal;
	viewPos      = (gl_ModelViewMatrix * gl_Vertex).xyz;
}
]]

local fragmentShader = [[
#version 120

uniform sampler2D albedoTex;
uniform sampler2D normalTex;
uniform sampler2D materialTex;
uniform sampler2D detailTex;
uniform sampler2D detailColourTex;
uniform sampler2D detailDistributionTex;
uniform sampler2D detailDirtTex;
uniform sampler2DShadow shadowTex;

uniform mat4 shadowMatrix;
uniform mat4 viewInverse;

uniform vec3 sunDirView;
uniform vec3 sunDiffuse;
uniform vec3 sunAmbient;
uniform vec3 upDirView;

uniform float detailScaleFine;
uniform float detailScaleCoarse;
uniform float detailStrength;
uniform float detailColourEnabled;
uniform float detailDirtEnabled;
uniform float detailPitDensity;
uniform float detailPitDepth;
uniform float detailPitRoughness;
uniform vec3 detailPitColourStrength;
uniform float detailDirtNormalStrength;
uniform float detailDirtRoughness;
uniform float detailDirtAlbedoStrength;
uniform float roughnessBias;
uniform float shadowDensity;
uniform float shadowBias;
uniform float ambientScale;
uniform float shadowsEnabled;
uniform float debugView;

varying vec3 viewNormal;
varying vec3 viewTangent;
varying vec3 viewBitangent;
varying vec2 texCoord;
varying vec3 objectPos;
varying vec3 objectNormal;
varying vec3 viewPos;

const float PI = 3.14159265359;
const vec3 F0_DIELECTRIC = vec3(0.04);
const float COLOUR_DETAIL_SECONDARY_SCALE = 0.61803398875;
const float PIT_COLOUR_STRENGTH_REFERENCE = 3.75;

// Mortar's tiling detail, relative to the stone's.
//
// Finer, so the two materials differ in feature size rather than only in strength -- that is
// what actually reads as a different material. And weaker, because a mortar bed is a narrow
// strip usually seen at a grazing angle, where a full-strength detail normal contributes
// almost no apparent shape but plenty of aliasing.
const float MORTAR_DETAIL_TILE = 2.6;
const float MORTAR_DETAIL_STRENGTH = 0.35;

// The two UV debug views answer different questions, so they are separate views.
//
// The gradient is a sawtooth: it says which way u and v run and where they wrap, but it
// has no features to measure against, so it cannot show stretch or a seam mismatch.
// Repeated a few times so the wrap is visible at all.
const float UV_GRADIENT_REPEAT = 8.0;

// The checker is the measuring instrument. Squares are a known reference, so a face
// reads as square (uniform texel density), rectangular (stretched), sheared, or coarser
// than its neighbour, and a seam shows up as squares that fail to line up across it.
//
// One square per 32 texels of a 2048 atlas, which puts a handful of squares across each
// island here rather than a moiré of sub-pixel ones.
const float UV_CHECKER_CELLS = 64.0;
const vec3 UV_CHECKER_DARK = vec3(0.15);
const vec3 UV_CHECKER_LIGHT = vec3(0.85);

vec3 uvChecker(vec2 uv)
{
	vec2 cell = floor(uv * UV_CHECKER_CELLS);
	float check = mod(cell.x + cell.y, 2.0);
	return mix(UV_CHECKER_DARK, UV_CHECKER_LIGHT, check);
}

float distributionGGX(float NdotH, float alpha)
{
	float a2 = alpha * alpha;
	float d = NdotH * NdotH * (a2 - 1.0) + 1.0;
	return a2 / max(PI * d * d, 1e-7);
}

float visibilitySmithGGX(float NdotV, float NdotL, float alpha)
{
	float a2 = alpha * alpha;
	float lambdaV = NdotL * sqrt(NdotV * NdotV * (1.0 - a2) + a2);
	float lambdaL = NdotV * sqrt(NdotL * NdotL * (1.0 - a2) + a2);
	return 0.5 / max(lambdaV + lambdaL, 1e-5);
}

vec3 fresnelSchlick(vec3 f0, float VdotH)
{
	return f0 + (vec3(1.0) - f0) * pow(1.0 - VdotH, 5.0);
}

vec2 envBRDFApprox(float NdotV, float roughness)
{
	const vec4 c0 = vec4(-1.0, -0.0275, -0.572, 0.022);
	const vec4 c1 = vec4(1.0, 0.0425, 1.04, -0.04);
	vec4 r = roughness * c0 + c1;
	float a004 = min(r.x * r.x, exp2(-9.28 * NdotV)) * r.x + r.y;
	return vec2(-1.04, 1.04) * a004 + r.zw;
}

// Projected from object space, so detail size is independent of the UV layout.
vec4 sampleDetail(vec3 position, vec3 normal, float scale)
{
	vec3 weights = abs(normalize(normal));
	weights /= max(weights.x + weights.y + weights.z, 1e-5);

	vec3 p = position * scale;
	return texture2D(detailTex, p.yz) * weights.x
	     + texture2D(detailTex, p.zx) * weights.y
	     + texture2D(detailTex, p.xy) * weights.z;
}

vec4 sampleDetailColour(vec3 position, vec3 normal, float scale)
{
	vec3 weights = abs(normalize(normal));
	weights /= max(weights.x + weights.y + weights.z, 1e-5);

	vec3 p = position * scale;
	return texture2D(detailColourTex, p.yz) * weights.x
	     + texture2D(detailColourTex, p.zx) * weights.y
	     + texture2D(detailColourTex, p.xy) * weights.z;
}

vec4 sampleDetailDirt(vec3 position, vec3 normal, float scale)
{
	vec3 weights = abs(normalize(normal));
	weights /= max(weights.x + weights.y + weights.z, 1e-5);

	vec3 p = position * scale;
	return texture2D(detailDirtTex, p.yz) * weights.x
	     + texture2D(detailDirtTex, p.zx) * weights.y
	     + texture2D(detailDirtTex, p.xy) * weights.z;
}

float detailDistributionDensity(vec2 uv, float density)
{
	float distribution = texture2D(detailDistributionTex, uv).r;
	float feathered = clamp((distribution - 0.16) / (0.78 - 0.16), 0.0, 1.0);
	float baseline = max(0.08, min(0.14, density * 0.30));
	float maximum = max(baseline, min(0.82, 0.30 + density * 1.65));
	return mix(baseline, maximum, feathered);
}

vec3 blendNormals(vec3 base, vec3 detail)
{
	return normalize(vec3(base.xy + detail.xy, base.z * detail.z));
}

void main()
{
	// tex1 stores sRGB; the engine binds it without a decode.
	vec3 albedo = pow(texture2D(albedoTex, texCoord).rgb, vec3(2.2));
	vec3 material = texture2D(materialTex, texCoord).rgb;
	float occlusion = material.g;

	// B carries which material this texel is: 0 stone, 1 mortar.
	//
	// Everything else about a material bakes into the maps, which is why mortar already
	// differs in colour, roughness and base normal without the shader knowing anything. The
	// tiling detail is the exception -- it is sampled here, per pixel, and was applied
	// identically everywhere. So a different material still wore the stone's grain, and on a
	// thin mortar bed seen near edge-on that grain is also what aliased and shimmered.
	float mortar = clamp(material.b, 0.0, 1.0);

	vec3 baseTangentNormal = texture2D(normalTex, texCoord).xyz * 2.0 - 1.0;

	// Mortar is sampled at a different scale, not merely weaker. It is an aggregate and
	// mottles at a few elmos where dressed stone weathers across tens, and feature *size* is
	// what the eye reads as a different material long before a change in strength does.
	//
	// Sampled twice and *the results* blended, rather than blending the scale and sampling
	// once. The mask is mipmapped along with the rest of the material map, so at distance its
	// clean 0 and 1 average into fractions; feeding those into the scale produced a tiling
	// that matched neither material and slid around as the mip level changed, which is what
	// made the beds shimmer and swim with zoom. Blending two correctly filtered samples is
	// stable, because each one is a valid appearance at every level and a partial mask just
	// crossfades between them.
	vec4 stoneFine = sampleDetail(objectPos, objectNormal, detailScaleFine);
	vec4 mortarFine = sampleDetail(objectPos, objectNormal, detailScaleFine * MORTAR_DETAIL_TILE);
	vec4 fineDetail = mix(stoneFine, mortarFine, mortar);
	vec4 coarseDetail = sampleDetail(objectPos, objectNormal, detailScaleCoarse);
	vec3 detailNormal = mix(
		fineDetail.xyz * 2.0 - 1.0,
		coarseDetail.xyz * 2.0 - 1.0,
		clamp(coarseDetail.a, 0.0, 1.0)
	);
	vec3 dirtClasses = vec3(0.0);
	float dirtFactor = 0.0;
	float dirtAlbedoFactor = 0.0;
	if (detailDirtEnabled > 0.5) {
		vec4 dirtA = sampleDetailDirt(objectPos, objectNormal, detailScaleFine);
		vec4 dirtB = sampleDetailDirt(
			objectPos, objectNormal, detailScaleFine * COLOUR_DETAIL_SECONDARY_SCALE);
		vec4 dirt = vec4(max(dirtA.rgb, dirtB.rgb), max(dirtA.a, dirtB.a));
		float faceBias = 0.05 + 0.95 * abs(normalize(objectNormal).y);
		float dirtDensity = detailDistributionDensity(texCoord, detailPitDensity) * faceBias;
		float dirtThreshold = 1.0 - dirtDensity;
		vec3 dirtPresent = step(vec3(dirtThreshold), dirt.rgb);
		dirtClasses = clamp(dirt.rgb * dirtPresent, vec3(0.0), vec3(1.0));
		dirtFactor = clamp(
			dirtClasses.r * 0.35 + dirtClasses.g * 0.72 + dirtClasses.b,
			0.0,
			1.0
		);
		// The red class is pixel-scale grit. Leave it continuous for albedo so it averages into a
		// middle tone at distance; the selected classes above still drive localized dents and
		// roughness.
		dirtAlbedoFactor = max(max(dirtClasses.g, dirtClasses.b), dirt.r * dirtDensity);
	}
	// And weaker on mortar: a bed is a narrow strip, usually seen at a grazing angle, so
	// full-strength normal perturbation there buys almost no shape and a lot of shimmer.
	detailNormal.xy *= detailStrength * mix(1.0, MORTAR_DETAIL_STRENGTH, mortar)
		* (1.0 + dirtFactor * detailDirtNormalStrength);

	vec3 tangentNormal = blendNormals(baseTangentNormal, normalize(detailNormal));

	// The colour tile is white outside a pit and black at its centre. It is localized dirt,
	// not another broad base-colour layer: the distribution map chooses where it may appear.
	float pitFactor = 0.0;
	if (detailColourEnabled > 0.5) {
		vec4 pitA = sampleDetailColour(objectPos, objectNormal, detailScaleFine);
		vec4 pitB = sampleDetailColour(
			objectPos, objectNormal, detailScaleFine * COLOUR_DETAIL_SECONDARY_SCALE);
		// The tile RGB is an independent per-mark value: white is clean, darker RGB is a darker
		// grain. Alpha remains the sparse occurrence/shape signal used by the distribution gate.
		vec4 pit = vec4(min(pitA.rgb, pitB.rgb), max(pitA.a, pitB.a));
		// The atlas distribution favours the top island, but triplanar projection can make the
		// same sparse tile look denser on a long rim. Keep edge pits subdued without removing them.
		float faceBias = 0.05 + 0.95 * abs(normalize(objectNormal).y);
		vec3 pitDarkness = vec3(1.0) - clamp(pit.rgb, vec3(0.0), vec3(1.0));
		float pitStrength = dot(detailPitColourStrength, vec3(0.3333333333))
			/ PIT_COLOUR_STRENGTH_REFERENCE;
		vec3 pitTint = clamp(
			vec3(1.0) - pitDarkness * vec3(pitStrength),
			vec3(0.0),
			vec3(1.0)
		);
		float pitDensity = detailDistributionDensity(texCoord, detailPitDensity) * faceBias;
		float pitPresent = step(1.0 - pitDensity, clamp(pit.a, 0.0, 1.0));
		pitFactor = pitPresent * clamp(pit.a, 0.0, 1.0);
		float pitAmount = clamp(pitFactor * detailPitDepth, 0.0, 1.0);
		albedo *= mix(vec3(1.0), pitTint, pitAmount);
	}
	albedo *= 1.0 - dirtAlbedoFactor * detailDirtAlbedoStrength;

	float roughness = clamp(
		material.r + roughnessBias + (mix(fineDetail.a, coarseDetail.a, 0.5) - 0.5) * 0.28
			+ pitFactor * detailPitRoughness + dirtFactor * detailDirtRoughness,
		0.045,
		1.0
	);

	mat3 tbn = mat3(normalize(viewTangent), normalize(viewBitangent), normalize(viewNormal));
	vec3 N = normalize(tbn * tangentNormal);

	vec3 V = vec3(0.0, 0.0, 1.0);
	vec3 L = normalize(sunDirView);
	vec3 H = normalize(L + V);

	float NdotL = max(dot(N, L), 0.0);
	float NdotV = max(dot(N, V), 1e-4);
	float NdotH = max(dot(N, H), 0.0);
	float VdotH = max(dot(V, H), 0.0);

	// With shadows off the engine binds nothing to $shadow and every lookup reads 0,
	// so the whole model would go black -- hence the guard rather than a blind read.
	//
	// The `xy += 0.5` and `shadow2DProj` are not optional decoration: they are the
	// engine's own convention (ModelVertProg.glsl:31, ModelFragProg.glsl:34). Without
	// the offset the lookup lands half a shadow map away from the fragment, which is
	// why this shader appeared to have no self-shadowing at all.
	float occluded = 1.0;
	if (shadowsEnabled > 0.5) {
		vec4 world = viewInverse * vec4(viewPos, 1.0);

		// Normal-offset bias: sample from slightly off the surface, or a face
		// shadows itself and the result is the speckled fringe of shadow acne.
		// Weighted towards grazing incidence, which is where the shadow map's
		// texel footprint on the surface is largest.
		//
		// Offset along the *geometric* normal, never the normal-mapped one. The shadow
		// map records where the geometry is; it has never heard of the detail texture.
		// Biasing along the shaded normal made the offset direction jitter from pixel to
		// pixel with the detail normal -- at detailStrength 4 it swings hard -- so
		// neighbouring pixels were pushed different distances and some cleared the depth
		// comparison while others did not. That is the stippled fringe, and it tracked
		// the grain rather than the geometry.
		vec3 geometricNormal = normalize(viewNormal);
		float geometricNdotL = max(dot(geometricNormal, L), 0.0);
		vec3 worldNormal = normalize((viewInverse * vec4(geometricNormal, 0.0)).xyz);
		world.xyz += worldNormal * shadowBias * (0.25 + (1.0 - geometricNdotL));

		vec4 shadowVertexPos = shadowMatrix * world;
		shadowVertexPos.xy += vec2(0.5);
		occluded = shadow2DProj(shadowTex, shadowVertexPos).r;
	}

	// Terminator softening, kept separate from the lookup so the Shadow debug view
	// shows real occlusion rather than a copy of NdotL.
	float shadowed = mix(1.0, min(occluded, smoothstep(0.0, 0.35, NdotL)), shadowDensity);

	float alpha = roughness * roughness;
	vec3 F = fresnelSchlick(F0_DIELECTRIC, VdotH);
	vec3 specular = F * distributionGGX(NdotH, alpha) * visibilitySmithGGX(NdotV, NdotL, alpha);
	vec3 diffuse = (vec3(1.0) - F) * albedo;

	// Scaled by PI to match the engine's non-normalised diffuse convention.
	vec3 direct = (diffuse + specular * PI) * sunDiffuse * NdotL * shadowed;

	float sky = 0.5 + 0.5 * dot(N, normalize(upDirView));
	vec3 ambientLight = sunAmbient * (0.6 + 0.8 * sky) * occlusion * ambientScale;
	vec2 envBRDF = envBRDFApprox(NdotV, roughness);
	vec3 ambient = albedo * ambientLight + ambientLight * (F0_DIELECTRIC * envBRDF.x + envBRDF.y);

	vec3 color = direct + ambient;

	if (debugView > 0.5) {
		if (debugView < 1.5)      color = albedo;
		else if (debugView < 2.5) color = N * 0.5 + 0.5;
		else if (debugView < 3.5) color = normalize(detailNormal) * 0.5 + 0.5;
		else if (debugView < 4.5) color = vec3(roughness);
		else if (debugView < 5.5) color = vec3(occlusion);
		else if (debugView < 6.5) color = vec3(occluded);
		else if (debugView < 7.5) color = normalize(viewTangent) * 0.5 + 0.5;
		else if (debugView < 8.5) color = vec3(fract(texCoord * UV_GRADIENT_REPEAT), 0.0);
		else                      color = uvChecker(texCoord);
		gl_FragColor = vec4(color, 1.0);
		return;
	}

	gl_FragColor = vec4(pow(color, vec3(1.0 / 2.2)), 1.0);
}
]]

local function uniformLocation(name)
	if uniforms[name] == nil then
		uniforms[name] = gl.GetUniformLocation(shader, name)
	end
	return uniforms[name]
end

local function customNumber(custom, key, fallback)
	local value = tonumber(custom[key])
	if value == nil then
		return fallback
	end
	return value
end

local function collectFeatureMaps()
	local found = 0
	for id = 1, #FeatureDefs do
		local def = FeatureDefs[id]
		local custom = def and def.customParams
		-- `normaltex` alone is not ours to key on -- it is the standard Custom Unit
		-- Shaders customparam, so anything else in the game that sets it for CUS's
		-- benefit (a tree, say) would match too. `author` is what genassets actually
		-- stamps on the featureDefs it writes; nothing else has reason to set it.
		if custom and custom.normaltex and custom.author == "genassets" then
			featureMaps[id] = {
				normal = custom.normaltex,
				material = custom.materialtex,
				detail = custom.detailtex,
				detailColour = custom.detailcolortex,
				detailDirt = custom.detaildirttex,
				detailDistribution = custom.detaildisttex,
				detailTileFine = customNumber(custom, "detail_tile_elmos", params.detailTileFine),
				detailStrength = customNumber(custom, "detail_strength", params.detailStrength),
				detailPitDensity = customNumber(custom, "detail_pit_density", params.detailPitDensity),
				detailPitDepth = customNumber(custom, "detail_pit_depth", params.detailPitDepth),
				detailPitRoughness = customNumber(custom, "detail_pit_roughness", params.detailPitRoughness),
				detailPitColourStrength = {
					customNumber(custom, "detail_pit_colour_strength_r", params.detailPitColourStrength[1]),
					customNumber(custom, "detail_pit_colour_strength_g", params.detailPitColourStrength[2]),
					customNumber(custom, "detail_pit_colour_strength_b", params.detailPitColourStrength[3]),
				},
				detailDirtNormalStrength = customNumber(custom, "detail_dirt_normal_strength", params.detailDirtNormalStrength),
				detailDirtRoughness = customNumber(custom, "detail_dirt_roughness", params.detailDirtRoughness),
				detailDirtAlbedoStrength = customNumber(custom, "detail_dirt_albedo_strength", params.detailDirtAlbedoStrength),
			}
			found = found + 1
		end
	end
	return found
end

local function compileShader()
	shader = gl.CreateShader({
		vertex = vertexShader,
		fragment = fragmentShader,
		uniformInt = {
			albedoTex = 0,
			normalTex = NORMAL_TEXUNIT,
			materialTex = MATERIAL_TEXUNIT,
			detailTex = DETAIL_TEXUNIT,
			detailColourTex = DETAIL_COLOUR_TEXUNIT,
			detailDistributionTex = DETAIL_DISTRIBUTION_TEXUNIT,
			detailDirtTex = DETAIL_DIRT_TEXUNIT,
			shadowTex = SHADOW_TEXUNIT,
		},
	})

	if not shader then
		Spring.Echo("[sb-asset-shader] compile failed: " .. tostring(gl.GetShaderLog()))
		return false
	end

	uniforms = {}
	Spring.Echo("[sb-asset-shader] compiled")
	return true
end

local function applyMaterial(featureID, featureDefID)
	local maps = featureMaps[featureDefID]
	if not maps or applied[featureID] then
		return
	end

	Spring.FeatureRendering.SetLODCount(featureID, 1)
	local texunits = {
		[0] = ("%%%d:0"):format(-featureDefID),
		[NORMAL_TEXUNIT] = maps.normal,
		[MATERIAL_TEXUNIT] = maps.material,
		[DETAIL_TEXUNIT] = maps.detail,
		[SHADOW_TEXUNIT] = "$shadow",
	}
	if maps.detailColour then
		texunits[DETAIL_COLOUR_TEXUNIT] = maps.detailColour
	end
	if maps.detailDistribution then
		texunits[DETAIL_DISTRIBUTION_TEXUNIT] = maps.detailDistribution
	end
	if maps.detailDirt then
		texunits[DETAIL_DIRT_TEXUNIT] = maps.detailDirt
	end
	Spring.FeatureRendering.SetMaterial(featureID, 1, "opaque", {
		shader = shader,
		texunits = texunits,
		usecamera = true,
	})
	if Spring.FeatureRendering.SetForwardMaterialUniform then
		local hasColour = maps.detailColour and maps.detailDistribution and 1.0 or 0.0
		local hasDirt = maps.detailDirt and maps.detailDistribution and 1.0 or 0.0
		Spring.FeatureRendering.SetForwardMaterialUniform(featureID, "opaque", 1,
			"detailColourEnabled", GL_FLOAT, hasColour)
		Spring.FeatureRendering.SetForwardMaterialUniform(featureID, "opaque", 1,
			"detailDirtEnabled", GL_FLOAT, hasDirt)
		Spring.FeatureRendering.SetForwardMaterialUniform(featureID, "opaque", 1,
			"detailScaleFine", GL_FLOAT, 1.0 / math.max(maps.detailTileFine, 0.01))
		Spring.FeatureRendering.SetForwardMaterialUniform(featureID, "opaque", 1,
			"detailStrength", GL_FLOAT, maps.detailStrength)
		Spring.FeatureRendering.SetForwardMaterialUniform(featureID, "opaque", 1,
			"detailPitDensity", GL_FLOAT, maps.detailPitDensity)
		Spring.FeatureRendering.SetForwardMaterialUniform(featureID, "opaque", 1,
			"detailPitDepth", GL_FLOAT, maps.detailPitDepth)
		Spring.FeatureRendering.SetForwardMaterialUniform(featureID, "opaque", 1,
			"detailPitRoughness", GL_FLOAT, maps.detailPitRoughness)
		Spring.FeatureRendering.SetForwardMaterialUniform(featureID, "opaque", 1,
			"detailPitColourStrength", GL_FLOAT_VEC3, maps.detailPitColourStrength)
		Spring.FeatureRendering.SetForwardMaterialUniform(featureID, "opaque", 1,
			"detailDirtNormalStrength", GL_FLOAT, maps.detailDirtNormalStrength)
		Spring.FeatureRendering.SetForwardMaterialUniform(featureID, "opaque", 1,
			"detailDirtRoughness", GL_FLOAT, maps.detailDirtRoughness)
		Spring.FeatureRendering.SetForwardMaterialUniform(featureID, "opaque", 1,
			"detailDirtAlbedoStrength", GL_FLOAT, maps.detailDirtAlbedoStrength)
	end
	applied[featureID] = true
end

local function clearMaterials()
	for featureID in pairs(applied) do
		Spring.FeatureRendering.SetLODCount(featureID, 0)
	end
	applied = {}
end

local function applyAll()
	for _, featureID in ipairs(Spring.GetAllFeatures()) do
		applyMaterial(featureID, Spring.GetFeatureDefID(featureID))
	end
end

local function worldDirToView(dx, dy, dz)
	-- gl.GetMatrixData returns 16 loose numbers, not a table.
	local m = { gl.GetMatrixData("camera") }
	if #m < 16 then
		return dx, dy, dz
	end
	return
		m[1] * dx + m[5] * dy + m[9] * dz,
		m[2] * dx + m[6] * dy + m[10] * dz,
		m[3] * dx + m[7] * dy + m[11] * dz
end

--- Panel → shader, forwarded across the sync boundary by the synced half above.
local function recvParams(_, msg)
	if not json then
		VFS.Include("libs_sb/json.lua", nil, VFS.ZIP)
	end
	local ok, envelope = pcall(json.decode, msg:sub(#MESSAGE_PREFIX + 1))
	if not ok or type(envelope) ~= "table" then
		return
	end

	-- Own tag, not `command`: that one belongs to SB.commandManager, which would
	-- resolve the payload as a Lua command class and error on every field edit.
	local data = envelope.data
	if envelope.tag ~= "assetShader" or type(data) ~= "table" then
		return
	end

	for key, value in pairs(data) do
		if params[key] ~= nil then
			params[key] = value
		end
	end

	Spring.Log("sb-asset-shader", LOG.NOTICE, ("params enabled=%s debugView=%s detail=%s"):format(
		tostring(params.enabled), tostring(params.debugView), tostring(params.detailStrength)))

	if params.enabled then
		applyAll()
	else
		clearMaterials()
	end
end

function gadget:Initialize()
	if not gl.CreateShader or not Spring.FeatureRendering then
		gadgetHandler:RemoveGadget()
		return
	end
	if collectFeatureMaps() == 0 or not compileShader() then
		gadgetHandler:RemoveGadget()
		return
	end
	gadgetHandler:AddSyncAction(SYNC_ACTION, recvParams)
	-- Say so out loud. Self-shadowing silently does nothing when the engine has no
	-- shadow map, and "no shadows" then looks like a shader bug rather than a setting.
	if not Spring.HaveShadows() then
		Spring.Log("sb-asset-shader", LOG.WARNING,
			"engine shadows are off (config Shadows=" .. tostring(Spring.GetConfigInt("Shadows", 2)) ..
			"); self-shadowing is disabled")
	end
	applyAll()
end

function gadget:FeatureCreated(featureID)
	if shader and params.enabled then
		applyMaterial(featureID, Spring.GetFeatureDefID(featureID))
	end
end

function gadget:FeatureDestroyed(featureID)
	applied[featureID] = nil
end

function gadget:DrawGenesis()
	if not shader or not params.enabled then
		return
	end

	local dx, dy, dz = gl.GetSun("pos")
	if not dx then
		return
	end

	local ar, ag, ab = gl.GetSun("ambient", "unit")
	local dr, dg, db = gl.GetSun("diffuse", "unit")
	local vx, vy, vz = worldDirToView(dx, dy, dz)
	local ux, uy, uz = worldDirToView(0, 1, 0)

	gl.UseShader(shader)
	gl.Uniform(uniformLocation("sunDirView"), vx, vy, vz)
	gl.Uniform(uniformLocation("upDirView"), ux, uy, uz)
	gl.Uniform(uniformLocation("sunAmbient"), ar or 0.3, ag or 0.3, ab or 0.3)
	gl.Uniform(uniformLocation("sunDiffuse"), dr or 1.0, dg or 1.0, db or 1.0)
	gl.Uniform(uniformLocation("detailScaleFine"), 1.0 / math.max(params.detailTileFine, 0.01))
	gl.Uniform(uniformLocation("detailScaleCoarse"), 1.0 / math.max(params.detailTileCoarse, 0.01))
	gl.Uniform(uniformLocation("detailStrength"), params.detailStrength)
	gl.Uniform(uniformLocation("detailColourEnabled"), 0.0)
	gl.Uniform(uniformLocation("detailDirtEnabled"), 0.0)
	gl.Uniform(uniformLocation("detailPitDensity"), params.detailPitDensity)
	gl.Uniform(uniformLocation("detailPitDepth"), params.detailPitDepth)
	gl.Uniform(uniformLocation("detailPitRoughness"), params.detailPitRoughness)
	gl.Uniform(uniformLocation("detailPitColourStrength"),
		params.detailPitColourStrength[1],
		params.detailPitColourStrength[2],
		params.detailPitColourStrength[3])
	gl.Uniform(uniformLocation("detailDirtNormalStrength"), params.detailDirtNormalStrength)
	gl.Uniform(uniformLocation("detailDirtRoughness"), params.detailDirtRoughness)
	gl.Uniform(uniformLocation("detailDirtAlbedoStrength"), params.detailDirtAlbedoStrength)
	gl.Uniform(uniformLocation("roughnessBias"), params.roughnessBias)
	gl.Uniform(uniformLocation("shadowDensity"), params.shadowDensity)
	gl.Uniform(uniformLocation("shadowBias"), params.shadowBias)
	gl.Uniform(uniformLocation("ambientScale"), params.ambientScale)
	gl.Uniform(uniformLocation("debugView"), params.debugView)
	gl.Uniform(
		uniformLocation("shadowsEnabled"),
		-- Runtime state, not the config value: `Shadows` defaults to 2 and can be
		-- -1 (force off), so reading the int says what was asked for rather than
		-- whether a shadow map actually exists to sample.
		Spring.HaveShadows() and 1.0 or 0.0
	)
	gl.UniformMatrix(uniformLocation("shadowMatrix"), "shadow")
	gl.UniformMatrix(uniformLocation("viewInverse"), "viewinverse")
	gl.UseShader(0)
end

function gadget:Shutdown()
	if shader then
		clearMaterials()
		gl.DeleteShader(shader)
		shader = nil
	end
end
