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

local params = {
	enabled = true,
	debugView = 0,
	detailTileFine = 2.5,
	detailTileCoarse = 9.0,
	detailStrength = 1.0,
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

vec3 blendNormals(vec3 base, vec3 detail)
{
	return normalize(vec3(base.xy + detail.xy, base.z * detail.z));
}

void main()
{
	// tex1 stores sRGB; the engine binds it without a decode.
	vec3 albedo = pow(texture2D(albedoTex, texCoord).rgb, vec3(2.2));
	vec2 material = texture2D(materialTex, texCoord).rg;
	float occlusion = material.g;

	vec3 baseTangentNormal = texture2D(normalTex, texCoord).xyz * 2.0 - 1.0;

	vec4 fineDetail = sampleDetail(objectPos, objectNormal, detailScaleFine);
	vec4 coarseDetail = sampleDetail(objectPos, objectNormal, detailScaleCoarse);
	vec3 detailNormal = mix(
		fineDetail.xyz * 2.0 - 1.0,
		coarseDetail.xyz * 2.0 - 1.0,
		clamp(coarseDetail.a, 0.0, 1.0)
	);
	detailNormal.xy *= detailStrength;

	vec3 tangentNormal = blendNormals(baseTangentNormal, normalize(detailNormal));

	float roughness = clamp(
		material.r + roughnessBias + (mix(fineDetail.a, coarseDetail.a, 0.5) - 0.5) * 0.28,
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
		vec3 worldNormal = normalize((viewInverse * vec4(N, 0.0)).xyz);
		world.xyz += worldNormal * shadowBias * (0.25 + (1.0 - NdotL));

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

local function collectFeatureMaps()
	local found = 0
	for id = 1, #FeatureDefs do
		local def = FeatureDefs[id]
		local custom = def and def.customParams
		if custom and custom.normaltex then
			featureMaps[id] = {
				normal = custom.normaltex,
				material = custom.materialtex,
				detail = custom.detailtex,
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
	Spring.FeatureRendering.SetMaterial(featureID, 1, "opaque", {
		shader = shader,
		texunits = {
			[0] = ("%%%d:0"):format(-featureDefID),
			[NORMAL_TEXUNIT] = maps.normal,
			[MATERIAL_TEXUNIT] = maps.material,
			[DETAIL_TEXUNIT] = maps.detail,
			[SHADOW_TEXUNIT] = "$shadow",
		},
		usecamera = true,
	})
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
	if not shader then
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
