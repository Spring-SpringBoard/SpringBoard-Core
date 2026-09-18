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
local GLOW_TEXUNIT = 9
local SHIP_DETAIL_TEXUNIT = 10
local METAL_TEXUNIT = 11
local SHIP_SURFACE_TEXUNIT = 12

-- Raw GL enums, because `SetForwardMaterialUniform` takes the type as a plain int and
-- the `GL` table stops at FLOAT_VEC4 -- it never exports FLOAT_VEC3. Spelling both out
-- here beats mixing `GL.FLOAT` with a bare number for its neighbour.
local GL_FLOAT = 0x1406
local GL_FLOAT_VEC3 = 0x8B51
local GL_INT = 0x1404

local params = {
	enabled = true,
	debugView = 0,
	detailTileFine = 2.5,
	detailTileCoarse = 9.0,
	-- Mip bias for the triplanar detail lookups, and how many tiles per pixel the layer is
	-- allowed to reach before it fades out. See the note beside `detailLodBias` in the shader:
	-- this used to be a hard-coded -8, which forced mip 0 at every distance and turned the
	-- detail into per-pixel noise that the GGX lobe read as white sparkle. -0.5 is the usual
	-- mild sharpening; the fade takes over where the tile stops being resolvable.
	detailLodBias = -0.5,
	detailFadeTiles = 0.7,
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
	-- The lowest roughness any surface may reach. Raising this was tried as a fix for the white
	-- speckle and measured to buy exactly nothing: with the Toksvig widening in place the count
	-- is zero at 0.045, and without it 0.12 and 0.045 both leave 11 speckles per million. So it
	-- stays where it was. A polished rim is allowed to be polished; what was never allowed is a
	-- polished rim whose sub-pixel normal spread goes unaccounted for.
	roughnessFloor = 0.045,
	-- Diagnostic: 0 switches off the Toksvig widening, so its share of the fix can be measured
	-- separately from the roughness floor and the one-sided detail term.
	toksvig = 1.0,
	-- How long the tiling detail normals are at mip 0, measured rather than assumed. See the note
	-- in `toksvigRoughness`: this is what the Toksvig length is divided by, so that the term
	-- responds to mip filtering and not to the texture's own compression loss.
	detailSpreadBaseline = 0.945,
	-- Diagnostic: 0 shades every texel as a dielectric again, which is what the engine did before
	-- the metallic map was read, for telling its contribution apart from everything else.
	metal = true,
	-- On, but only because the shadow map is now big enough to be worth sampling.
	--
	-- This was off for a while, and the reason was real: at the engine's default ShadowMapSize of
	-- 2048 the pass contributed nothing but acne, and no bias setting bought a shadow without the
	-- stripes. That was never a bias problem. The engine fits one shadow map to the camera
	-- frustum, so a 2048 map put a texel several elmos across on a 200-elmo ship -- wider than the
	-- panel relief it was meant to shadow, which is the definition of a surface that can only
	-- shadow itself. Measured on the turntable as local contrast over the shadows-off baseline:
	-- +0.0040 at 2048, +0.0015 at 4096, +0.0003 at 8192. The project now asks for 8192
	-- (`tools/dev/springsettings.cfg`), where the banding across the shield face is gone and
	-- about a sixth of the lit pixels still differ from shadows off -- real occlusion, no acne.
	shadowDensity = 1.0,
	shadowBias = 1.5,
	ambientScale = 1.0,
	-- Hemisphere ambient: the share a surface facing away from the sky still gets, and how much
	-- more one facing it collects. See the note beside `ambientLight`.
	--
	-- Raised from 0.01 / 0.10 (with `envScale` from 1 to 6) by A/B on the Phalanx: at the old
	-- levels the side away from the sun -- the whole keel -- was black, form and all. These lift it
	-- to a readable dark grey and leave the lit side and its contrast where they were, because the
	-- sun at `directScale` 8 still dominates anything it reaches.
	ambientFloor = 0.25,
	ambientSky = 1.0,
	-- How strongly the sun lights the surface, against that ambient. See the note by `direct`.
	directScale = 8.0,
	-- Per-surface-type tiling detail for assets that ship a family strip (`shipdetailtex`).
	-- Additive to everything else; toggled at runtime with `/luarules assetfamilydetail`, so its
	-- cost can be read straight off the frame rate.
	familyDetail = true,
	familyDetailStrength = 1.0,
	-- The armour layer, for assets that ship one (`shipdetailsurfacetex`). Off only to compare against.
	armourDetail = true,
	-- Diagnostic: scales the direct specular term. 0 isolates whether a bright artefact is a
	-- highlight or is in the maps.
	specularScale = 1.0,
	-- Diagnostic: 0 drops the genassets tiling detail layer (normal and roughness), leaving the
	-- per-family layer and the maps, to tell the two apart.
	baseDetail = true,
	-- Specular anti-aliasing: how strongly normal variance across a pixel widens the highlight,
	-- and the most it may add to alpha squared. The paper's 2.0 / 0.18 cleared the white snow on
	-- the software rasteriser and not on a GTX 1660 Ti, where GPU derivatives see less of the
	-- variance. Picked by A/B on that GPU, one frame, shield ship spine: 8 / 0.35 still sparkled,
	-- 16 / 0.6 cleared it with the detail intact.
	specularAA = 16.0,
	specularAAMax = 0.6,
	-- Both default on; `sb_asset_dirt=0` / `sb_asset_colour_detail=0` take them out.
	dirt = true,
	colourDetail = true,
	-- AgX, as Blender renders these. 0 falls back to the old plain gamma.
	--
	-- These five numbers are one setting and were picked together, against a Blender render of
	-- the same maps rather than by eye: nearly no ambient, a sun eight times what it was, and an
	-- exposure that places the result low on the AgX curve. Separately none of them work. Raising
	-- the sun alone lifts the mid-tones with the highlights and the ship just gets brighter;
	-- lowering the exposure alone compresses the range and the ship just gets flatter. Together
	-- they give what the studio render has and this shader did not: most of the hull dark, with a
	-- narrow bright edge that does not clip.
	--
	-- Ambient was near zero because these ships are in space, with nothing out there to light the
	-- side facing away from the sun. That matched the studio render but left the keel a black
	-- hole in play, so it now fills to a dark grey (see `ambientFloor`). It still stays well under
	-- the sun: a strong hemisphere fill is what once made every metal surface read as grey plastic.
	tonemap = 1.0,
	tonemapExposure = 0.28,
	-- How much environment a metal reflects. Space is dark; see the note beside `envLight`.
	-- Metal takes almost nothing from the diffuse ambient, so this is what lifts a metal keel.
	envScale = 6.0,
}

-- Start-up overrides from modoptions, so a headless run can A/B a single frame without the panel.
do
	local options = Spring.GetModOptions() or {}
	if options.sb_asset_armour then
		params.armourDetail = options.sb_asset_armour ~= "0"
	end
	if options.sb_asset_family_detail then
		params.familyDetail = options.sb_asset_family_detail ~= "0"
	end
	if options.sb_asset_specular then
		params.specularScale = tonumber(options.sb_asset_specular) or params.specularScale
	end
	if options.sb_asset_base_detail then
		params.baseDetail = options.sb_asset_base_detail ~= "0"
	end
	params.specularAA = tonumber(options.sb_asset_spec_aa) or params.specularAA
	params.specularAAMax = tonumber(options.sb_asset_spec_aa_max) or params.specularAAMax
	-- A/B for the detail mip fix: `sb_asset_detail_lod=-8` restores the old forced-mip-0
	-- behaviour and `sb_asset_detail_fade=1e9` disables the fade, so one headless frame can be
	-- captured either way without editing the shader.
	params.detailLodBias = tonumber(options.sb_asset_detail_lod) or params.detailLodBias
	params.detailFadeTiles = tonumber(options.sb_asset_detail_fade) or params.detailFadeTiles
	-- The panel's debug views, reachable from a headless run. `4` is the roughness the shader
	-- actually ends up with, which is not the baked map: the detail, dirt and family layers all
	-- add to it, and the clamp at the bottom can pull a surface to near-mirror that the map said
	-- was satin. Capturing that view is the only way to measure what the lighting really sees.
	params.debugView = tonumber(options.sb_asset_debug_view) or params.debugView
	params.tonemap = tonumber(options.sb_asset_tonemap) or params.tonemap
	params.tonemapExposure =
		tonumber(options.sb_asset_exposure) or params.tonemapExposure
	params.envScale = tonumber(options.sb_asset_env) or params.envScale
	params.shadowDensity = tonumber(options.sb_asset_shadow_density) or params.shadowDensity
	params.shadowBias = tonumber(options.sb_asset_shadow_bias) or params.shadowBias
	params.roughnessBias = tonumber(options.sb_asset_roughness_bias) or params.roughnessBias
	params.roughnessFloor = tonumber(options.sb_asset_roughness_floor) or params.roughnessFloor
	params.toksvig = tonumber(options.sb_asset_toksvig) or params.toksvig
	params.detailSpreadBaseline =
		tonumber(options.sb_asset_spread_baseline) or params.detailSpreadBaseline
	params.ambientFloor = tonumber(options.sb_asset_ambient_floor) or params.ambientFloor
	params.ambientSky = tonumber(options.sb_asset_ambient_sky) or params.ambientSky
	params.directScale = tonumber(options.sb_asset_direct) or params.directScale
	if options.sb_asset_metal then
		params.metal = options.sb_asset_metal ~= "0"
	end
	-- The two sparse layers, separately switchable. They sample the same tiling atlas at the
	-- same two scales, so on a hull they produce the same artefact if they produce one at all --
	-- a regular lattice of one mark per tile -- and the only way to tell which is responsible is
	-- to turn one off.
	if options.sb_asset_dirt then
		params.dirt = options.sb_asset_dirt ~= "0"
	end
	if options.sb_asset_colour_detail then
		params.colourDetail = options.sb_asset_colour_detail ~= "0"
	end
	params.familyDetailStrength =
		tonumber(options.sb_asset_family_strength) or params.familyDetailStrength
	params.detailStrength = tonumber(options.sb_asset_detail_strength) or params.detailStrength
end

local shader
local featureMaps = {}
-- A generated unit borrows the maps of the featureDef that shares its name: genassets stamps
-- the detail textures and tuning on the feature, and the unit is the same model flying.
local unitMaps = {}
local applied = {}
local appliedUnits = {}
local reportedUnit = false
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
#extension GL_ARB_shader_texture_lod : enable

uniform sampler2D albedoTex;
uniform sampler2D normalTex;
uniform sampler2D materialTex;
uniform sampler2D metalTex;
uniform float metalEnabled;
uniform sampler2D detailTex;
uniform sampler2D detailColourTex;
uniform sampler2D detailDistributionTex;
uniform sampler2D detailDirtTex;
uniform sampler2DShadow shadowTex;
// Units only: the engine's tex2, whose R channel is self-illumination.
uniform sampler2D glowTex;

// Linked by the engine by name, per unit, from the owning team.
uniform vec4 teamColor;
// 1 for units: tex1 alpha is the team-colour share, as in the engine's own model shader.
// 0 for features, whose alpha means nothing to this shader.
uniform float teamMix;
uniform float glowEnabled;

// Per-surface-type detail. `familyDetail` is per object: 1 when the asset ships a family strip,
// and then the material map's B channel is a family slot (index / 8), not the stone/mortar mask.
// `familyDetailEnabled` is the global runtime switch.
uniform sampler2D shipDetailTex;
uniform float familyDetail;
uniform float familyDetailEnabled;
uniform float familyDetailStrength;
uniform float specularScale;
uniform float baseDetailEnabled;
uniform float specularAA;
uniform float specularAAMax;
// (tile, stride, inset) of one slot in the horizontal strip, as fractions of its width.
uniform vec3 shipDetailSlot;
uniform float shipGrainScale;
uniform float shipFittingScale;
uniform float shipFittingSlot;
// The armour layer. One family whose surface noise is drawn here, per pixel and in object space,
// instead of baked: baked, it is only as sharp as the atlas, which on a close camera is blur.
//
// The surface strip has the detail strip's layout. R is the slot's albedo as a ratio to its own
// mean, stored halved so "no change" is mid-grey; G is where it is bare metal; B the occlusion
// inside its own relief; A how much of it glows (ship-game-assets `textures.ENGINE_SURFACE`).
uniform sampler2D shipSurfaceTex;
uniform float shipArmourEnabled;
uniform float shipArmourSlot;
uniform float shipArmourScale;
uniform float shipArmourContrast;

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
uniform float roughnessFloor;
uniform float toksvigEnabled;
uniform float detailSpreadBaseline;
uniform float shadowDensity;
uniform float shadowBias;
uniform float ambientScale;
uniform float ambientFloor;
uniform float ambientSky;
uniform float directScale;
uniform float shadowsEnabled;
uniform float debugView;
uniform float tonemap;
uniform float tonemapExposure;
uniform float envScale;

varying vec3 viewNormal;
varying vec3 viewTangent;
varying vec3 viewBitangent;
varying vec2 texCoord;
varying vec3 objectPos;
varying vec3 objectNormal;
varying vec3 viewPos;

const float PI = 3.14159265359;
const vec3 F0_DIELECTRIC = vec3(0.04);

// Roughness widened by the normal variation a mip filter has already averaged away (Toksvig).
//
// This is the part screen-space specular AA structurally cannot do. That term measures how much
// N changes *between* neighbouring pixels, with `dFdx`; once a detail tile is finer than a pixel
// the variation is *within* one pixel and the 2x2 quad cannot see it at all. Different hardware
// disagrees about how much it sees, which is why the AA constants had to be tuned per GPU and
// still left snow on one of them.
//
// A mip-filtered normal map answers it directly: averaging normals that point different ways
// produces a *shorter* vector, so the length of the sample is a measurement of the spread that
// was filtered out. Convert that to an effective Blinn exponent and back, and the lobe widens by
// exactly as much as the filtering justifies -- automatically, per pixel, with no constant to
// tune and nothing to disagree about.
float toksvigRoughness(float spread, float roughness)
{
	// Divided by the texture's own baseline before it means anything.
	//
	// The theory says a unit-length normal map only shortens when a mip filter averages it, so
	// the length is a measurement of what the filter removed. These textures are not unit length
	// to begin with: measured with `sb_asset_debug_view=13`, the tiling detail normal is 0.945
	// long at point-blank range and 0.937 across a hull at gameplay distance. Almost all of that
	// deficit is the texture (DXT block compression does not preserve unit length), and almost
	// none of it is filtering.
	//
	// Read raw, that constant 0.94 made this a *blanket* roughness increase -- median 0.44 to
	// 0.62 over the whole ship, at every distance including the closest. It did remove the white
	// speckle, but by dulling everything rather than by widening the lobe where the lobe was
	// actually too narrow. Normalising by the baseline leaves only the part that varies, which
	// is the part that means something.
	float len = clamp(spread / max(detailSpreadBaseline, 1e-3), 1e-4, 1.0);
	if (len > 0.9999) {
		return roughness;
	}
	float power = 2.0 / max(roughness * roughness, 1e-4) - 2.0;
	float factor = len / (len + power * (1.0 - len));
	return sqrt(2.0 / (factor * power + 2.0));
}
const float COLOUR_DETAIL_SECONDARY_SCALE = 0.61803398875;
const float PIT_COLOUR_STRENGTH_REFERENCE = 3.75;

// Width of the soft band replacing the old hard pit gate. Wide enough that a minified pit fades
// rather than popping off, narrow enough that pits stay separate marks up close.
const float PIT_GATE_SOFTNESS = 0.45;

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

// AgX, the display transform Blender renders these assets through.
//
// Not decoration. Measured on matched whole-ship framings, the studio render puts its 95th
// percentile at 0.525 and its brightest pixels at 0.818 -- a wide gap, because AgX rolls the top
// off. This shader used a plain `pow(color, 1/2.2)`, which does not roll off at all: it reached
// p95 0.471 with a tail at 0.937, so the highlights were already clipping while the mid-tones
// were still flat. That is why the engine looked flatter than Blender, and moving the ambient and
// the sun around cannot fix it -- raising the sun for contrast only clips sooner.
//
// The standard minimal AgX: a matrix into its working space, a log2 encode over the exposure
// range it is defined on, a fitted sigmoid for the contrast curve, and the inverse matrix back.
const mat3 AGX_TRANSFORM = mat3(
	0.842479062253094, 0.0423282422610123, 0.0423756549057051,
	0.0784335999999992, 0.878468636469772, 0.0784336000000000,
	0.0792237451477643, 0.0791661274605434, 0.879142973793104
);
const mat3 AGX_TRANSFORM_INVERSE = mat3(
	 1.19687900512017,  -0.0528968517574562, -0.0529716355144438,
	-0.0980208811401368, 1.15190312990417,   -0.0980434501171241,
	-0.0990297440797205, -0.0989611768448433,  1.15107367264116
);
const float AGX_MIN_EV = -12.47393;
const float AGX_MAX_EV = 4.026069;

vec3 agxContrast(vec3 x)
{
	vec3 x2 = x * x;
	vec3 x4 = x2 * x2;
	return 15.5 * x4 * x2 - 40.14 * x4 * x + 31.96 * x4 - 6.868 * x2 * x + 0.4298 * x2
		+ 0.1191 * x - 0.00232;
}

vec3 agx(vec3 colour)
{
	vec3 working = AGX_TRANSFORM * max(colour, vec3(0.0));
	working = clamp(log2(max(working, vec3(1e-10))), AGX_MIN_EV, AGX_MAX_EV);
	working = (working - AGX_MIN_EV) / (AGX_MAX_EV - AGX_MIN_EV);
	working = agxContrast(working);
	return clamp(AGX_TRANSFORM_INVERSE * working, vec3(0.0), vec3(1.0));
}

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

// Mip selection for the triplanar detail lookups, and why it is not simply the hardware's.
//
// The detail tile is 2.5 elmos across (`detailTileFine`), so a 165-elmo ship carries about
// sixty tiles end to end. At a gameplay camera that ship is a few hundred pixels wide, which
// puts several *tiles* -- tens of texels -- inside every pixel. The hardware LOD of 6 to 8 is
// therefore correct, and the flat (0.5, 0.5, 1.0) it returns is correct too: that is what a
// noise tile averages to once it is smaller than a pixel. Explicit `dFdx`/`dFdy` gradients
// agreed with it because there was never anything wrong with the derivative.
//
// The old fix read that flatness as a bug and forced mip 0 with a -8 bias. That does put grain
// back on screen, but it is grain sampled tens of texels apart: uncorrelated noise, different
// every frame, and a normal map made of noise throws a GGX highlight at a random subset of
// pixels. That is the white speckle on the hulls. The specular-AA term below fights it and
// cannot win, because the input is aliased before the lighting ever sees it.
//
// So: sample at the level the hardware asks for, with a mild sharpening bias, and fade the
// layer out as it stops being resolvable rather than letting it alias. Close up the grain is
// unchanged -- it is mip 0 there either way; what goes away is the noise at range, where the
// detail could not have been seen anyway.
uniform float detailLodBias;
uniform float detailFadeTiles;

// How much of the detail layer survives at this pixel: 1 while a tile still covers several
// pixels, falling to 0 once tiles are smaller than one. Measured in tiles per pixel from the
// same object-space position the projection reads, so it costs two derivatives and no lookup.
float detailResolvable(vec3 position, float scale)
{
	vec3 dx = dFdx(position) * scale;
	vec3 dy = dFdy(position) * scale;
	float tilesPerPixel = sqrt(max(dot(dx, dx), dot(dy, dy)));
	return clamp(1.0 - tilesPerPixel / max(detailFadeTiles, 1e-3), 0.0, 1.0);
}

vec4 sampleDetailPlane(sampler2D tex, vec2 uv)
{
	return texture2D(tex, uv, detailLodBias);
}

// Projected from object space, so detail size is independent of the UV layout.
//
// `spread` comes back as the weighted mean of the three plane samples' *individual* lengths, and
// that distinction is the whole point. `length()` of the blended result is short even at mip 0,
// because three normals from three different projections never agree -- so reading the blend's
// length as a filtering measurement reports heavy sub-pixel variance on a perfectly sharp
// texture, and the Toksvig widening then fires everywhere at once. Measured that way it raised
// roughness by 0.35 at the closest framing, where by construction it should do nothing at all.
// Each plane's own sample is unit length until a mip filter shortens it, which is the thing
// being measured.
vec4 sampleDetail(vec3 position, vec3 normal, float scale, out float spread)
{
	vec3 weights = abs(normalize(normal));
	weights /= max(weights.x + weights.y + weights.z, 1e-5);

	vec3 p = position * scale;
	vec4 a = sampleDetailPlane(detailTex, p.yz);
	vec4 b = sampleDetailPlane(detailTex, p.zx);
	vec4 c = sampleDetailPlane(detailTex, p.xy);
	spread = length(a.xyz * 2.0 - 1.0) * weights.x
	       + length(b.xyz * 2.0 - 1.0) * weights.y
	       + length(c.xyz * 2.0 - 1.0) * weights.z;
	return a * weights.x + b * weights.y + c * weights.z;
}

vec4 sampleDetailColour(vec3 position, vec3 normal, float scale)
{
	vec3 weights = abs(normalize(normal));
	weights /= max(weights.x + weights.y + weights.z, 1e-5);

	vec3 p = position * scale;
	return sampleDetailPlane(detailColourTex, p.yz) * weights.x
	     + sampleDetailPlane(detailColourTex, p.zx) * weights.y
	     + sampleDetailPlane(detailColourTex, p.xy) * weights.z;
}

vec4 sampleDetailDirt(vec3 position, vec3 normal, float scale)
{
	vec3 weights = abs(normalize(normal));
	weights /= max(weights.x + weights.y + weights.z, 1e-5);

	vec3 p = position * scale;
	return sampleDetailPlane(detailDirtTex, p.yz) * weights.x
	     + sampleDetailPlane(detailDirtTex, p.zx) * weights.y
	     + sampleDetailPlane(detailDirtTex, p.xy) * weights.z;
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

// How much grain each family carries, by slot: brushed plate, machined, honed bore, composite.
// Slot 4 (flat: lamps, glow) gets none. Mirrors `families.py`.
const vec4 FAMILY_GRAIN = vec4(1.0, 1.0, 1.0, 0.8);

// One slot of the family strip, with explicit gradients. The slot address wraps `u` with fract,
// and the derivative of a wrapped coordinate spikes at every wrap, which would drop the lookup to
// the smallest mip along a line through every repeat. Gradients of the unwrapped coordinate,
// scaled into the slot, give the filter what it should have seen.
vec4 sampleShipSlot(vec2 uv, vec2 duvdx, vec2 duvdy, float slot)
{
	float tile = shipDetailSlot.x;
	vec2 atlasUv = vec2(fract(uv.x) * tile + slot * shipDetailSlot.y + shipDetailSlot.z, uv.y);
	return texture2DGradARB(shipDetailTex, atlasUv,
		vec2(duvdx.x * tile, duvdx.y), vec2(duvdy.x * tile, duvdy.y));
}

// Stochastic sampling (Heitz & Neyret 2018), so a tiling texture shows no repeat.
//
// The plane is covered in triangles a third of a tile across. Each triangle corner gets a random
// offset into the tile, and a pixel blends the three corners' samples by its barycentric weights:
// neighbouring triangles show unrelated parts of the tile, and nothing is seamed because the
// weights are continuous. Measured with ship-game-assets' `tools/tiling_demo.py` on the scanned
// steel, correlation between one tile and the next goes from 0.886 tiled plainly, and 0.332 with
// the two-scale blend this replaces, to 0.000. The studio shader uses the same grid and cell size.
//
// The offsets are constant within a triangle, so the lookup keeps the unshifted coordinate's
// gradients: the mip level is chosen as if nothing had moved, and nothing flickers at the edges.
const float STOCHASTIC_CELL = 0.35;

vec2 stochasticHash(vec2 p)
{
	return fract(sin(vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)))) * 43758.5453);
}

// Weights belong to *vertices*, and the two triangles of a cell share (1, 0) and (0, 1). Their
// weights must agree along the shared edge or the blend jumps there and the grid is drawn as
// hard-edged patches -- the studio port got this wrong first, with the upper pair swapped.
void stochasticGrid(vec2 uv, out vec3 w, out vec2 o1, out vec2 o2, out vec2 o3)
{
	vec2 s = uv / STOCHASTIC_CELL;
	vec2 skewed = vec2(s.x - 0.57735027 * s.y, 1.15470054 * s.y);
	vec2 base = floor(skewed);
	vec2 f = skewed - base;
	float z = 1.0 - f.x - f.y;
	float lower = step(0.0, z);
	float upper = 1.0 - lower;
	w = vec3(abs(z), mix(1.0 - f.y, f.y, lower), mix(1.0 - f.x, f.x, lower));
	o1 = stochasticHash(base + vec2(upper, upper));
	o2 = stochasticHash(base + vec2(upper, lower));
	o3 = stochasticHash(base + vec2(lower, upper));
}

// The surface strip's counterpart of `sampleShipSlot`: same layout, same gradient handling.
vec4 sampleShipSurfaceSlot(vec2 uv, vec2 duvdx, vec2 duvdy, float slot)
{
	float tile = shipDetailSlot.x;
	vec2 atlasUv = vec2(fract(uv.x) * tile + slot * shipDetailSlot.y + shipDetailSlot.z, uv.y);
	return texture2DGradARB(shipSurfaceTex, atlasUv,
		vec2(duvdx.x * tile, duvdx.y), vec2(duvdy.x * tile, duvdy.y));
}

// Triplanar from object space, sharpened so the three projections do not smear into each other on
// the flat faces these hulls are made of. Three lookups.
vec4 sampleShipDetail(vec3 position, vec3 normal, float scale, float slot, out float spread)
{
	vec3 w = pow(abs(normalize(normal)), vec3(4.0));
	w /= max(w.x + w.y + w.z, 1e-5);
	vec3 p = position * scale;
	vec3 dpdx = dFdx(p);
	vec3 dpdy = dFdy(p);
	vec4 a = sampleShipSlot(p.yz, dpdx.yz, dpdy.yz, slot);
	vec4 b = sampleShipSlot(p.zx, dpdx.zx, dpdy.zx, slot);
	vec4 c = sampleShipSlot(p.xy, dpdx.xy, dpdy.xy, slot);
	// Per plane, for the reason in `sampleDetail`.
	spread = length(a.xyz * 2.0 - 1.0) * w.x
	       + length(b.xyz * 2.0 - 1.0) * w.y
	       + length(c.xyz * 2.0 - 1.0) * w.z;
	return a * w.x + b * w.y + c * w.z;
}

// One slot, stochastically, on one projection plane: detail (normal RGB, roughness A) and, when
// asked, the surface strip -- all from the same three texels, so relief, colour, metal and glow
// stay registered to each other.
//
// The blend is re-expanded about 0.5 by 1/sqrt(sum of squared weights), which undoes the variance
// three averaged samples lose. That is exact only about each channel's true mean, and it varies
// per pixel -- an error in the centre would come out shaped like the grid -- so the pipeline
// stores every such channel centred on 0.5 (ship-game-assets `textures.write_engine_detail`).
// Normal z is the exception: it is not centred, and every caller renormalises the normal anyway.
// So are the surface strip's metal, occlusion and glow: they are masks, not deviations, and are
// blended plainly -- a little softer at a triangle's middle, and never shifted off their mean.
vec4 stochasticShipSlot(vec2 uv, vec2 duvdx, vec2 duvdy, float slot, float wantSurface,
	out vec4 surface, out float spread)
{
	vec3 w;
	vec2 o1, o2, o3;
	stochasticGrid(uv, w, o1, o2, o3);
	vec4 a = sampleShipSlot(uv + o1, duvdx, duvdy, slot);
	vec4 b = sampleShipSlot(uv + o2, duvdx, duvdy, slot);
	vec4 c = sampleShipSlot(uv + o3, duvdx, duvdy, slot);
	float restore = inversesqrt(dot(w, w));
	vec4 blended = a * w.x + b * w.y + c * w.z;
	vec4 result = 0.5 + (blended - 0.5) * restore;
	result.z = blended.z;
	// Filtering shortens each sample's own normal; the blend's shortening is a different thing and
	// the restore has already dealt with it. So the Toksvig spread is taken per sample.
	spread = length(a.xyz * 2.0 - 1.0) * w.x
	       + length(b.xyz * 2.0 - 1.0) * w.y
	       + length(c.xyz * 2.0 - 1.0) * w.z;
	surface = vec4(0.5, 0.0, 1.0, 0.0);
	if (wantSurface > 0.5) {
		vec4 sa = sampleShipSurfaceSlot(uv + o1, duvdx, duvdy, slot);
		vec4 sb = sampleShipSurfaceSlot(uv + o2, duvdx, duvdy, slot);
		vec4 sc = sampleShipSurfaceSlot(uv + o3, duvdx, duvdy, slot);
		surface = sa * w.x + sb * w.y + sc * w.z;
		surface.r = 0.5 + (surface.r - 0.5) * restore;
	}
	return result;
}

// Triplanar, stochastic. Three lookups per plane, so up to nine -- but these hulls are made of flat
// faces, and after the weights are sharpened almost every pixel has one plane carrying all of it.
// Planes under 1% are skipped outright, which puts most of the hull at three lookups. The
// gradients are taken before the branches, where they are defined for every pixel.
vec4 stochasticShipDetail(vec3 position, vec3 normal, float scale, float slot, float wantSurface,
	out vec4 surface, out float spread)
{
	vec3 w = pow(abs(normalize(normal)), vec3(4.0));
	w /= max(w.x + w.y + w.z, 1e-5);
	w *= step(0.01, w);
	w /= max(w.x + w.y + w.z, 1e-5);
	vec3 p = position * scale;
	vec3 dpdx = dFdx(p);
	vec3 dpdy = dFdy(p);
	vec4 result = vec4(0.0);
	vec4 t;
	float s;
	surface = vec4(0.0);
	spread = 0.0;
	if (w.x > 0.0) {
		result += stochasticShipSlot(p.yz, dpdx.yz, dpdy.yz, slot, wantSurface, t, s) * w.x;
		surface += t * w.x;
		spread += s * w.x;
	}
	if (w.y > 0.0) {
		result += stochasticShipSlot(p.zx, dpdx.zx, dpdy.zx, slot, wantSurface, t, s) * w.y;
		surface += t * w.y;
		spread += s * w.y;
	}
	if (w.z > 0.0) {
		result += stochasticShipSlot(p.xy, dpdx.xy, dpdy.xy, slot, wantSurface, t, s) * w.z;
		surface += t * w.z;
		spread += s * w.z;
	}
	return result;
}

void main()
{
	// tex1 stores sRGB; the engine binds it without a decode.
	vec4 albedoSample = texture2D(albedoTex, texCoord);
	vec3 albedo = pow(albedoSample.rgb, vec3(2.2));
	if (teamMix > 0.5) {
		albedo = mix(albedo, pow(teamColor.rgb, vec3(2.2)), clamp(albedoSample.a, 0.0, 1.0));
	}
	float glow = glowEnabled > 0.5 ? texture2D(glowTex, texCoord).r : 0.0;
	vec3 material = texture2D(materialTex, texCoord).rgb;
	float metalness = metalEnabled > 0.5 ? clamp(texture2D(metalTex, texCoord).r, 0.0, 1.0) : 0.0;
	float occlusion = material.g;

	// B carries which material this texel is: 0 stone, 1 mortar.
	//
	// Everything else about a material bakes into the maps, which is why mortar already
	// differs in colour, roughness and base normal without the shader knowing anything. The
	// tiling detail is the exception -- it is sampled here, per pixel, and was applied
	// identically everywhere. So a different material still wore the stone's grain, and on a
	// thin mortar bed seen near edge-on that grain is also what aliased and shimmered.
	float mortar = clamp(material.b, 0.0, 1.0);
	float family = -1.0;
	if (familyDetail > 0.5) {
		family = floor(material.b * 8.0 + 0.5);
		mortar = 0.0;
	}

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
	float stoneSpread, mortarSpread, coarseSpread;
	vec4 stoneFine = sampleDetail(objectPos, objectNormal, detailScaleFine, stoneSpread);
	vec4 mortarFine = sampleDetail(
		objectPos, objectNormal, detailScaleFine * MORTAR_DETAIL_TILE, mortarSpread);
	vec4 fineDetail = mix(stoneFine, mortarFine, mortar);
	vec4 coarseDetail = sampleDetail(objectPos, objectNormal, detailScaleCoarse, coarseSpread);
	vec3 detailNormal = mix(
		fineDetail.xyz * 2.0 - 1.0,
		coarseDetail.xyz * 2.0 - 1.0,
		clamp(coarseDetail.a, 0.0, 1.0)
	);
	// Blended the same way the samples themselves are, so it tracks which layer is actually
	// being shown. Never `length(detailNormal)`: see the note on `sampleDetail`.
	float detailSpread = clamp(
		mix(mix(stoneSpread, mortarSpread, mortar), coarseSpread, clamp(coarseDetail.a, 0.0, 1.0)),
		1e-4,
		1.0
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
	// Faded out once the tile is finer than a pixel: past that point the sample is noise, not
	// grain, and a noisy normal is what put white specular sparkle on every hull.
	detailNormal.xy *= baseDetailEnabled * detailStrength * mix(1.0, MORTAR_DETAIL_STRENGTH, mortar)
		* (1.0 + dirtFactor * detailDirtNormalStrength)
		* detailResolvable(objectPos, detailScaleFine);

	vec3 tangentNormal = blendNormals(baseTangentNormal, normalize(detailNormal));

	// Per-family runtime detail, on top of the detail already baked into the atlas: the grain of
	// the substance on its fine tile, and machinery's fittings on their coarse one. Sharp however
	// close the camera gets, because nothing here went through the atlas.
	//
	// Faded by resolvability like the base layer, and for a stronger reason: measured with
	// `tools/speckle.py` on the ship-assets turntable, switching this layer off took the spike
	// count from 163 per million hull pixels to 61, while switching off *all* direct specular
	// only reached 132. So this layer was the largest single source of the white speckle, and it
	// was aliasing through albedo and roughness as well as through the highlight. Its gradients
	// were already correct; what it lacked was somewhere to go once its tile is finer than a
	// pixel. "Sharp however close the camera gets" is untouched -- the fade is 1 whenever the
	// grain covers more than a pixel, which is every case where it can actually be seen.
	float shipRoughness = 0.0;
	float grainSpread = 1.0;
	if (familyDetail > 0.5 && familyDetailEnabled > 0.5 && family < 3.5) {
		float grainFade = detailResolvable(objectPos, shipGrainScale);
		float grain = FAMILY_GRAIN[int(family)] * familyDetailStrength * grainFade;
		vec4 grainSurface;
		vec4 g = stochasticShipDetail(
			objectPos, objectNormal, shipGrainScale, family, 0.0, grainSurface, grainSpread);
		vec3 gn = g.xyz * 2.0 - 1.0;
		grainSpread = clamp(grainSpread, 1e-4, 1.0);
		tangentNormal = blendNormals(tangentNormal, normalize(vec3(gn.xy * grain, gn.z)));
		shipRoughness += (g.a - 0.5) * 0.35 * grain;
		if (abs(family - 1.0) < 0.5) {
			float fittingSpread;
			vec4 f = sampleShipDetail(
				objectPos, objectNormal, shipFittingScale, shipFittingSlot, fittingSpread);
			vec3 fn = f.xyz * 2.0 - 1.0;
			float fittingFade = detailResolvable(objectPos, shipFittingScale);
			tangentNormal = blendNormals(
				tangentNormal, normalize(vec3(fn.xy * familyDetailStrength * fittingFade, fn.z)));
			shipRoughness += (f.a - 0.5) * 0.25 * familyDetailStrength;
		}
	}

	// The armour layer: the scanned steel on a tile a few dozen elmos across, colour included.
	//
	// A tile this large repeats only a handful of times across a shield face -- few enough that the
	// eye finds the repeat and reads it as a printed pattern -- which is what the stochastic sampler
	// is for. It replaced two incommensurate copies averaged together, which measured 0.332
	// correlation between neighbouring tiles and visibly banded. Faded like every runtime layer
	// once its tile is finer than a pixel.
	if (shipArmourEnabled > 0.5 && abs(family - shipArmourSlot) < 0.5) {
		float fade = detailResolvable(objectPos, shipArmourScale);
		vec4 surface;
		float armourSpread;
		vec4 a = stochasticShipDetail(
			objectPos, objectNormal, shipArmourScale, shipArmourSlot, 1.0, surface, armourSpread);
		// Tone is stored halved: 0.5 is the slot's own mean, and 1.0 twice it.
		float ratio = 1.0 + (surface.r - 0.5) * 2.0 * shipArmourContrast;
		albedo *= mix(1.0, max(ratio, 0.0), fade);
		// Bare metal where the material is bare, its own crevices darker, any glow it carries.
		metalness = max(metalness, surface.g * fade);
		occlusion *= mix(1.0, surface.b, fade);
		glow = max(glow, surface.a * fade);
		vec3 an = a.xyz * 2.0 - 1.0;
		tangentNormal = blendNormals(tangentNormal,
			normalize(vec3(an.xy * familyDetailStrength * fade, an.z)));
		shipRoughness += (a.a - 0.5) * 0.35 * fade;
	}

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
		// Not `step(1.0 - pitDensity, pit.a)`. That is a hard threshold on a mip-filtered mask:
		// alpha peaks near 1 at a pit's centre but averages toward its mean as the tile minifies,
		// so beyond some distance it drops under the threshold and every pit switches off at
		// once. In-engine that read as pits on the near rim and a bare top face -- the surface
		// closest to camera kept them and the rest lost them, which looks like a projection bug
		// and is really a filtering cliff.
		//
		// A soft band keeps pits sparse where the mask is sharp, and lets them fade out with
		// distance instead of vanishing.
		float pitShape = smoothstep(1.0 - pitDensity - PIT_GATE_SOFTNESS, 1.0 - pitDensity,
			clamp(pit.a, 0.0, 1.0));
		pitFactor = pitShape * clamp(pit.a, 0.0, 1.0);
		float pitAmount = clamp(pitFactor * detailPitDepth, 0.0, 1.0);
		albedo *= mix(vec3(1.0), pitTint, pitAmount);
	}
	albedo *= 1.0 - dirtAlbedoFactor * detailDirtAlbedoStrength;

	// Grain, grit and wear can only ever make a surface *rougher*. They were signed -- the term
	// was centred on 0.5 and subtracted as often as it added -- so a detail layer meant to
	// represent a scuffed, cast or weathered surface was polishing it half the time. Measured
	// with `sb_asset_debug_view=4` over a full turntable: 18% of the visible hull came out below
	// 0.15 roughness and 2.3% was pinned at the clamp, against a baked map whose 5th percentile
	// is 0.14 and which is essentially never near-mirror. Nearly a fifth of the ship was being
	// shaded as polished chrome by layers that are supposed to dirty it.
	//
	// So the map's own value is a floor now, not a midpoint: the layers add to it.
	//
	// On its own this is worth little against the speckle -- 14 per million down to 11, with
	// specular AA disabled -- and it is kept for being right rather than for that. What actually
	// removes the speckle is the Toksvig widening below.
	float detailRoughness = max(mix(fineDetail.a, coarseDetail.a, 0.5) - 0.5, 0.0);
	float roughness = clamp(
		material.r + roughnessBias
			+ detailRoughness * 0.28 * baseDetailEnabled
			+ pitFactor * detailPitRoughness + dirtFactor * detailDirtRoughness
			+ max(shipRoughness, 0.0),
		roughnessFloor,
		1.0
	);

	// And widened by whatever sub-pixel normal spread the mip filters removed, from both tiling
	// layers. Where the detail is resolvable both lengths are 1 and this does nothing at all.
	if (toksvigEnabled > 0.5) {
		roughness = toksvigRoughness(detailSpread, roughness);
		roughness = toksvigRoughness(grainSpread, roughness);
	}

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

	// Specular anti-aliasing (Tokuyoshi & Kaplanyan). Detail normals vary faster than a pixel, so
	// within one pixel N swings through the half vector and a narrow GGX lobe lands full strength
	// on a few pixels and nothing on their neighbours: white grain on smooth metal. Measured by
	// A/B on one frame: the dots vanished with specular off and the detail stayed. Widening the
	// lobe by how much N changes across the pixel spreads that energy the way a mip would.
	vec3 dNdx = dFdx(N);
	vec3 dNdy = dFdy(N);
	float normalVariance = 0.25 * (dot(dNdx, dNdx) + dot(dNdy, dNdy));
	float alpha = sqrt(clamp(
		roughness * roughness * roughness * roughness
			+ min(specularAA * normalVariance, specularAAMax), 0.0, 1.0));
	// Metal or dielectric, per texel, instead of treating the whole ship as painted plastic.
	//
	// The pipeline has baked a metallic map all along -- `build.py` says so in a comment, and
	// then that "nothing in the engine reads it yet". Measured on the Shield Ship, 55.6% of its
	// texels are metal: every bare-steel rim, pipe, drum, nozzle and machinery housing. All of
	// it was being shaded with a 0.04 dielectric F0 and a full diffuse lobe, which is the
	// description of painted plastic, and it is most of why the engine came out flatter and half
	// as colourful as the Blender render of the same maps. A metal takes its specular colour
	// from its albedo and has no diffuse lobe at all.
	vec3 F0 = mix(F0_DIELECTRIC, albedo, metalness);
	vec3 F = fresnelSchlick(F0, VdotH);
	vec3 specular = F * distributionGGX(NdotH, alpha) * visibilitySmithGGX(NdotV, NdotL, alpha);
	vec3 diffuse = (vec3(1.0) - F) * albedo * (1.0 - metalness);

	// Scaled by PI to match the engine's non-normalised diffuse convention.
	// Scaled against the ambient, which is the whole point of having lowered the ambient's floor.
	//
	// Dropping the ambient alone darkened the lit side as much as the shadowed one -- measured,
	// the 5th percentile fell from 0.234 to 0.162 but the 95th fell from 0.484 to 0.403 with it,
	// so the ship got dimmer without gaining any range. Blender's render of the same maps sits at
	// a median of 0.199 *and* a 95th of 0.461: dark mid-tones with bright highlights over them.
	// That is a ratio between direct and ambient light, not a level.
	vec3 direct =
		(diffuse + specular * PI * specularScale) * sunDiffuse * directScale * NdotL * shadowed;

	// A hemisphere ambient with a real floor, not a near-flat one.
	//
	// This was `0.6 + 0.8 * sky`, so a surface facing straight down still collected 60% of the
	// ambient that one facing straight up did, and nothing on the ship could be dark. Measured
	// against a Blender render of the same maps: the engine's 5th-percentile luminance was 0.226
	// where Blender reached 0.080, and its whole tonal spread was 40% narrower. Mid-tones were
	// actually *brighter* than Blender's -- the ships were not dim, they were flat.
	vec3 up = normalize(upDirView);
	float sky = 0.5 + 0.5 * dot(N, up);
	vec3 ambientLight =
		sunAmbient * (ambientFloor + ambientSky * sky) * occlusion * ambientScale;

	// What a metal *is*, visually, is what it reflects -- so the environment term has to be
	// sampled along the reflection vector, not along the normal.
	//
	// Sampled along N it is a function of the surface's facing, which for a rough metal varies
	// slowly and identically to the diffuse term: every metal part came out the same flat grey
	// as the paint next to it, with no sheen and no sense of a surrounding. Along R it sweeps
	// the environment as the surface curves, which is what produces the bright streak down a
	// drum and the sharp fall-off either side of it -- the thing that reads as metal.
	//
	// `envScale` is separate from the diffuse ambient on purpose. These ships are in space: the
	// surroundings are nearly black, so a metal should be dark except where it catches the sun,
	// and the sun's own reflection is already provided by the direct GGX lobe. Lighting metal
	// with the same broad hemisphere as the paint is what made it read as grey plastic.
	vec3 reflection = reflect(-V, N);
	float envSky = 0.5 + 0.5 * dot(reflection, up);
	vec3 envLight =
		sunAmbient * (ambientFloor + ambientSky * envSky) * occlusion * ambientScale * envScale;

	vec2 envBRDF = envBRDFApprox(NdotV, roughness);
	vec3 ambient = albedo * ambientLight * (1.0 - metalness)
		+ envLight * (F0 * envBRDF.x + envBRDF.y);

	// Lamps, windows and drive grilles: lit whatever the sun is doing.
	vec3 color = direct + ambient + albedo * glow;

	if (debugView > 0.5) {
		if (debugView < 1.5)      color = albedo;
		else if (debugView < 2.5) color = N * 0.5 + 0.5;
		else if (debugView < 3.5) color = normalize(detailNormal) * 0.5 + 0.5;
		else if (debugView < 4.5) color = vec3(roughness);
		else if (debugView < 5.5) color = vec3(occlusion);
		else if (debugView < 6.5) color = vec3(occluded);
		else if (debugView < 7.5) color = normalize(viewTangent) * 0.5 + 0.5;
		else if (debugView < 8.5) color = vec3(fract(texCoord * UV_GRADIENT_REPEAT), 0.0);
		else if (debugView < 9.5) color = uvChecker(texCoord);
		// TEMPORARY diagnostic: raw triplanar inputs and the detail sample itself.
		else if (debugView < 10.5) color = fract(objectPos * 0.25);
		else if (debugView < 11.5) color = abs(normalize(objectNormal));
		else if (debugView < 12.5) color = stoneFine.rgb;
		// 13 and 14: the lengths the Toksvig widening is reading. Both should be 1 -- white --
		// wherever the tiling detail is resolvable, and fall off only as it stops being so. A
		// grey hull at point-blank range means the *source* normals are not unit length, which
		// is a texture problem and not a filtering one.
		else if (debugView < 13.5) color = vec3(detailSpread);
		else if (debugView < 14.5) color = vec3(grainSpread);
		// 15 and 16: the two sparse layers' own output, which is where a tiling lattice shows
		// up as a lattice. Both are meant to be scattered marks; a regular grid of identical
		// blobs in either means the tile is showing through its own distribution gate.
		else if (debugView < 15.5) color = vec3(dirtAlbedoFactor);
		else if (debugView < 16.5) color = vec3(pitFactor);
		// 17 and 18: metalness and the self-illum term. Metal loses its diffuse *and* most of
		// its ambient, so a patch of it reads as a dark mark with the albedo, roughness, normal
		// and occlusion of its neighbours -- invisible in every other view, and the reason this
		// one exists.
		else if (debugView < 17.5) color = vec3(metalness);
		else if (debugView < 18.5) color = vec3(glow);
		// 19: the same metal lookup with v flipped, kept as a standing test. A texture that
		// disagrees with the atlas only in its vertical origin is not obviously broken -- it is
		// a plausible map, correctly registered to *something*, reading the mirrored end of the
		// atlas -- and on a packed unwrap that means the surface wears someone else's islands.
		// This view found exactly that once: 17 was a lattice of diamonds on the shield and 19
		// was the calm black the map actually says. If they ever differ again, the map feeding
		// `metaltex` has been written in the wrong convention.
		else if (debugView < 19.5)
			color = vec3(texture2D(metalTex, vec2(texCoord.x, 1.0 - texCoord.y)).r);
		else                       color = vec3(detailScaleFine, detailStrength * 0.1, 0.0);
		gl_FragColor = vec4(color, 1.0);
		return;
	}

	// AgX already lands display-referred; the gamma path stays so the two can be compared on one
	// frame with `sb_asset_tonemap=0`.
	// AgX is defined on *scene-referred* radiance, where middle grey sits near 0.18. What this
	// shader accumulates is not scaled to that, so it has to be placed on the curve before the
	// curve can do anything useful: fed in raw, AgX lifted the mid-tones instead of deepening
	// them (median 0.346 to 0.388) even as the highlight roll-off worked as intended.
	vec3 shown = tonemap > 0.5
		? agx(color * tonemapExposure)
		: pow(color, vec3(1.0 / 2.2));
	gl_FragColor = vec4(shown, 1.0);
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
				metal = custom.metaltex,
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
				shipDetail = custom.shipdetailtex,
				shipDetailSlots = customNumber(custom, "shipdetail_slots", 1),
				shipDetailResolution = customNumber(custom, "shipdetail_resolution", 512),
				shipDetailPad = customNumber(custom, "shipdetail_pad", 0),
				shipFittingSlot = customNumber(custom, "shipdetail_fitting_slot", 0),
				shipGrainElmos = customNumber(custom, "shipdetail_grain_elmos", 2.0),
				shipFittingElmos = customNumber(custom, "shipdetail_fitting_elmos", 25.6),
				-- The armour layer: one family whose surface noise is drawn here, per pixel, on a
				-- coarse tile of its own, rather than baked into the atlas where it is only as
				-- sharp as the atlas is. The surface strip carries its colour, metal, occlusion
				-- and glow; the detail strip above carries its normal and roughness, same slot.
				shipSurface = custom.shipdetailsurfacetex,
				shipArmourSlot = customNumber(custom, "shipdetail_armour_slot", -1),
				shipArmourElmos = customNumber(custom, "shipdetail_armour_elmos", 24.0),
				shipArmourContrast = customNumber(custom, "shipdetail_armour_contrast", 1.0),
			}
			found = found + 1
		end
	end
	for id = 1, #UnitDefs do
		local def = UnitDefs[id]
		local feature = def and FeatureDefNames[def.name]
		if feature and featureMaps[feature.id] then
			unitMaps[id] = featureMaps[feature.id]
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
			glowTex = GLOW_TEXUNIT,
			shipDetailTex = SHIP_DETAIL_TEXUNIT,
			metalTex = METAL_TEXUNIT,
			shipSurfaceTex = SHIP_SURFACE_TEXUNIT,
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

--- Bind the material to one object. `isUnit` picks the rendering API, the model-texture id
--- sign the engine uses to tell a unitDef from a featureDef, and the unit-only inputs.
local function applyObjectMaterial(objectID, defID, isUnit)
	local maps = (isUnit and unitMaps or featureMaps)[defID]
	local done = isUnit and appliedUnits or applied
	if not maps or done[objectID] then
		return
	end
	local api = isUnit and Spring.UnitRendering or Spring.FeatureRendering
	local modelID = isUnit and defID or -defID

	api.SetLODCount(objectID, 1)
	local texunits = {
		[0] = ("%%%d:0"):format(modelID),
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
	if isUnit then
		texunits[GLOW_TEXUNIT] = ("%%%d:1"):format(modelID)
	end
	if maps.shipDetail then
		texunits[SHIP_DETAIL_TEXUNIT] = maps.shipDetail
	end
	if maps.metal then
		texunits[METAL_TEXUNIT] = maps.metal
	end
	if maps.shipSurface then
		texunits[SHIP_SURFACE_TEXUNIT] = maps.shipSurface
	end
	local material = {
		shader = shader,
		usecamera = true,
	}
	for unit, tex in pairs(texunits) do
		material["texunit" .. unit] = tex
	end
	api.SetMaterial(objectID, 1, "opaque", material)
	if api.SetForwardMaterialUniform then
		local hasColour =
			maps.detailColour and maps.detailDistribution and params.colourDetail and 1.0 or 0.0
		local hasDirt =
			maps.detailDirt and maps.detailDistribution and params.dirt and 1.0 or 0.0
		-- Off for any asset that ships no metallic map, so this cannot change how anything
		-- already in a project is drawn: without the map every texel reads as dielectric,
		-- exactly as before.
		local hasMetal = maps.metal and params.metal and 1.0 or 0.0
		-- The value is always a table, scalars included: the engine reads it with
		-- ParseFloatArray, which rejects anything that is not one.
		local function setUniform(name, glType, value)
			api.SetForwardMaterialUniform(objectID, "opaque", 1, name, glType, value)
		end
		setUniform("teamMix", GL_FLOAT, {isUnit and 1.0 or 0.0})
		setUniform("glowEnabled", GL_FLOAT, {isUnit and 1.0 or 0.0})
		setUniform("familyDetail", GL_FLOAT, {maps.shipDetail and 1.0 or 0.0})
		if maps.shipDetail then
			local pitch = maps.shipDetailResolution + 2 * maps.shipDetailPad
			local total = pitch * math.max(maps.shipDetailSlots, 1)
			setUniform("shipDetailSlot", GL_FLOAT_VEC3, {
				maps.shipDetailResolution / total, pitch / total, maps.shipDetailPad / total,
			})
			setUniform("shipGrainScale", GL_FLOAT, {1.0 / math.max(maps.shipGrainElmos, 0.01)})
			setUniform("shipFittingScale", GL_FLOAT, {1.0 / math.max(maps.shipFittingElmos, 0.01)})
			setUniform("shipFittingSlot", GL_FLOAT, {maps.shipFittingSlot})
			local armour = maps.shipSurface and maps.shipArmourSlot >= 0 and params.armourDetail
			setUniform("shipArmourEnabled", GL_FLOAT, {armour and 1.0 or 0.0})
			setUniform("shipArmourSlot", GL_FLOAT, {maps.shipArmourSlot})
			setUniform("shipArmourScale", GL_FLOAT, {1.0 / math.max(maps.shipArmourElmos, 0.01)})
			setUniform("shipArmourContrast", GL_FLOAT, {maps.shipArmourContrast})
		end
		setUniform("metalEnabled", GL_FLOAT, {hasMetal})
		setUniform("detailColourEnabled", GL_FLOAT, {hasColour})
		setUniform("detailDirtEnabled", GL_FLOAT, {hasDirt})
		setUniform("detailScaleFine", GL_FLOAT, {1.0 / math.max(maps.detailTileFine, 0.01)})
		setUniform("detailStrength", GL_FLOAT, {maps.detailStrength})
		setUniform("roughnessFloor", GL_FLOAT, {params.roughnessFloor})
		setUniform("toksvigEnabled", GL_FLOAT, {params.toksvig})
		setUniform("detailSpreadBaseline", GL_FLOAT, {params.detailSpreadBaseline})
		setUniform("detailLodBias", GL_FLOAT, {params.detailLodBias})
		setUniform("detailFadeTiles", GL_FLOAT, {params.detailFadeTiles})
		setUniform("detailPitDensity", GL_FLOAT, {maps.detailPitDensity})
		setUniform("detailPitDepth", GL_FLOAT, {maps.detailPitDepth})
		setUniform("detailPitRoughness", GL_FLOAT, {maps.detailPitRoughness})
		setUniform("detailPitColourStrength", GL_FLOAT_VEC3, maps.detailPitColourStrength)
		setUniform("detailDirtNormalStrength", GL_FLOAT, {maps.detailDirtNormalStrength})
		setUniform("detailDirtRoughness", GL_FLOAT, {maps.detailDirtRoughness})
		setUniform("detailDirtAlbedoStrength", GL_FLOAT, {maps.detailDirtAlbedoStrength})
	end
	done[objectID] = true
	if isUnit and not reportedUnit then
		reportedUnit = true
		Spring.Echo(("[sb-asset-shader] unit material applied to %s"):format(
			(UnitDefs[defID] or {}).name or tostring(defID)))
	end
end

local function applyMaterial(featureID, featureDefID)
	applyObjectMaterial(featureID, featureDefID, false)
end

local function applyUnitMaterial(unitID, unitDefID)
	applyObjectMaterial(unitID, unitDefID, true)
end

local function clearMaterials()
	for featureID in pairs(applied) do
		Spring.FeatureRendering.SetLODCount(featureID, 0)
	end
	for unitID in pairs(appliedUnits) do
		Spring.UnitRendering.SetLODCount(unitID, 0)
	end
	applied = {}
	appliedUnits = {}
end

local function applyAll()
	for _, featureID in ipairs(Spring.GetAllFeatures()) do
		applyMaterial(featureID, Spring.GetFeatureDefID(featureID))
	end
	for _, unitID in ipairs(Spring.GetAllUnits()) do
		applyUnitMaterial(unitID, Spring.GetUnitDefID(unitID))
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
	-- `/luarules assetfamilydetail` flips the per-family detail, for an A/B on looks and frame
	-- rate without restarting. Not on the panel yet: that lives in the Rust UI.
	gadgetHandler:AddChatAction("assetfamilydetail", function()
		params.familyDetail = not params.familyDetail
		Spring.Echo("[sb-asset-shader] family detail " .. (params.familyDetail and "on" or "off"))
	end)
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

function gadget:UnitCreated(unitID, unitDefID)
	if shader and params.enabled then
		applyUnitMaterial(unitID, unitDefID)
	end
end

function gadget:UnitDestroyed(unitID)
	appliedUnits[unitID] = nil
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
	gl.Uniform(uniformLocation("detailLodBias"), params.detailLodBias)
	gl.Uniform(uniformLocation("detailFadeTiles"), params.detailFadeTiles)
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
	gl.Uniform(uniformLocation("roughnessFloor"), params.roughnessFloor)
	gl.Uniform(uniformLocation("toksvigEnabled"), params.toksvig)
	gl.Uniform(uniformLocation("detailSpreadBaseline"), params.detailSpreadBaseline)
	gl.Uniform(uniformLocation("shadowDensity"), params.shadowDensity)
	gl.Uniform(uniformLocation("shadowBias"), params.shadowBias)
	gl.Uniform(uniformLocation("ambientScale"), params.ambientScale)
	gl.Uniform(uniformLocation("ambientSky"), params.ambientSky)
	gl.Uniform(uniformLocation("ambientFloor"), params.ambientFloor)
	gl.Uniform(uniformLocation("directScale"), params.directScale)
	gl.Uniform(uniformLocation("debugView"), params.debugView)
	gl.Uniform(uniformLocation("tonemap"), params.tonemap)
	gl.Uniform(uniformLocation("tonemapExposure"), params.tonemapExposure)
	gl.Uniform(uniformLocation("envScale"), params.envScale)
	gl.Uniform(uniformLocation("familyDetailEnabled"), params.familyDetail and 1.0 or 0.0)
	gl.Uniform(uniformLocation("familyDetailStrength"), params.familyDetailStrength)
	gl.Uniform(uniformLocation("specularScale"), params.specularScale)
	gl.Uniform(uniformLocation("baseDetailEnabled"), params.baseDetail and 1.0 or 0.0)
	gl.Uniform(uniformLocation("specularAA"), params.specularAA)
	gl.Uniform(uniformLocation("specularAAMax"), params.specularAAMax)
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
	gadgetHandler:RemoveChatAction("assetfamilydetail")
	if shader then
		clearMaterials()
		gl.DeleteShader(shader)
		shader = nil
	end
end
