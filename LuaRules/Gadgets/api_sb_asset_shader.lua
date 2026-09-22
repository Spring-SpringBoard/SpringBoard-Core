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

--- What this renderer offers the Rendering Lab: its material layers and light strengths, by
--- concept, and the shader's debug views by name. The game's Rust renderer offers the same ids
--- (`shipcore::lab::catalogue`), so the panel reads alike whichever is drawing.
local LAB_CONTROLS = {
	{ id = "material.metallic", name = "Metallic", category = "material", param = "metal",
		what = "Parts of the hull that are bare metal: they reflect the surroundings and take no diffuse light." },
	{ id = "material.base_detail", name = "Base detail", category = "material", param = "baseDetail",
		what = "Fine tiling relief and roughness over every surface." },
	{ id = "material.family_detail", name = "Family detail", category = "material", param = "familyDetail",
		what = "Each surface family with a relief of its own." },
	{ id = "material.armour_detail", name = "Armour detail", category = "material", param = "armourDetail",
		what = "The armour family's surface drawn per pixel rather than baked." },
	{ id = "material.dirt", name = "Dirt", category = "material", param = "dirt",
		what = "Grime gathered in corners and seams." },
	{ id = "material.pits", name = "Pits", category = "material", param = "colourDetail",
		what = "Small pits and scars in the surface." },
	{ id = "material.detail_strength", name = "Detail strength", category = "material", param = "detailStrength",
		min = 0, max = 8, what = "How strong the base detail relief is." },
	{ id = "material.roughness_floor", name = "Roughness floor", category = "material", param = "roughnessFloor",
		min = 0, max = 0.5, what = "The lowest roughness any surface may reach." },
	{ id = "lighting.ibl", name = "Environment (IBL)", category = "lighting", param = "ibl",
		what = "The surroundings lighting the hull from every direction." },
	{ id = "lighting.direct", name = "Sun strength", category = "lighting", param = "directScale",
		min = 0, max = 20, what = "How strongly the star lights a surface square to it." },
	{ id = "lighting.ambient_floor", name = "Ambient floor", category = "lighting", param = "ambientFloor",
		min = 0, max = 1, what = "What a surface facing away from the sky still gets." },
	{ id = "lighting.env", name = "Environment strength", category = "lighting", param = "envScale",
		min = 0, max = 20, what = "How much environment a metal reflects." },
	{ id = "lighting.shadow_bias", name = "Shadow bias", category = "lighting", param = "shadowBias",
		min = 0, max = 30, what = "How far a surface is pushed out of its own shadow." },
}
local LAB_VIEWS = {
	"final", "albedo", "normal", "detail_normal", "roughness", "occlusion", "shadow", "tangent",
	"uv_gradient", "uv_checker", "object_position", "object_normal", "detail_sample",
	"detail_spread", "grain_spread", "dirt", "pits", "metalness", "glow", "metalness_flipped",
}
local LAB_VIEW_NAMES = {
	"Final", "Albedo", "Normal", "Detail normal", "Roughness", "Occlusion", "Shadow",
	"Tangent frame", "UV gradient", "UV checker", "Object position", "Object normal",
	"Detail sample", "Detail spread", "Grain spread", "Dirt", "Pits", "Metalness", "Glow",
	"Metalness (v flipped)",
}
local LAB_REPLY_PREFIX = "springboard|lab|"

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
-- A cube map, so it may never share a unit with a 2D sampler.
local ENVIRONMENT_TEXUNIT = 13
-- The light the surroundings cast on every ship (ship-game-assets, `shipassets/space.py`).
local ENVIRONMENT_MAP = "bitmaps/gen_space_env.dds"

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
	shadowBias = 8.0,
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
	-- Light the ships from the environment map rather than from a hemisphere, if the map is
	-- installed; and how much of it a matt surface and a sheen take.
	ibl = true,
	iblDiffuse = 1.6,
	iblSpecular = 8.0,
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
	-- `sb_asset_lod=N` draws level of detail N at every distance, so a reduced hull can be
	-- looked at up close. 0 leaves the choice to distance. See `setupLevels`.
	-- The shader used to announce itself, its levels and its first unit on every boot. That is
	-- three lines of console for every run of every tool, and the console is for things that went
	-- wrong. `sb_asset_chatty=1` puts them back.
	params.chatty = options.sb_asset_chatty == "1"
	params.forcedLevel = tonumber(options.sb_asset_lod) or 0
	params.lodTint = options.sb_asset_lod_tint == "1"
	-- `sb_asset_levels=0` turns levels of detail off: every hull piece draws, for an A/B.
	params.levels = options.sb_asset_levels ~= "0"
	params.tonemap = tonumber(options.sb_asset_tonemap) or params.tonemap
	params.tonemapExposure =
		tonumber(options.sb_asset_exposure) or params.tonemapExposure
	params.envScale = tonumber(options.sb_asset_env) or params.envScale
	params.ibl = options.sb_asset_ibl ~= "0" and VFS.FileExists(ENVIRONMENT_MAP)
	params.iblDiffuse = tonumber(options.sb_asset_ibl_diffuse) or params.iblDiffuse
	params.iblSpecular = tonumber(options.sb_asset_ibl_specular) or params.iblSpecular
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

--- The GLSL lives beside this file, not inside it: `asset_shader.vert` and `asset_shader.frag`
--- under `luarules/shipassets`. A thousand lines of shader inside a Lua string is a thousand
--- lines no editor will highlight, no linter will read and no compiler will point at by line
--- number. `just sync-sb-shader` copies both files into SpringBoard beside its own copy of this
--- gadget, so the editor and the game run the same shader.
local SHADER_DIR = "luarules/shipassets/"

local function shaderSource(name)
	local text = VFS.LoadFile(SHADER_DIR .. name)
	if not text then
		Spring.Echo(("[sb-asset-shader] missing %s%s"):format(SHADER_DIR, name))
	end
	return text
end

--- Read when the shader is compiled, which only the unsynced half ever does.
local vertexShader, fragmentShader


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

--- A comma-separated customparam, as a list; `convert` maps each entry.
local function customList(custom, key, convert)
	local list = {}
	for entry in (custom[key] or ""):gmatch("[^,]+") do
		list[#list + 1] = convert and convert(entry) or entry
	end
	return list
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
				-- Reduced hulls, drawn from these distances on (`shipassets/lod.py`). See `setupLevels`.
				lodPieces = customList(custom, "lod_pieces"),
				lodDistances = customList(custom, "lod_distances", tonumber),
				lodOcclusion = customList(custom, "lod_occlusion", tonumber),
				lodShadowBias = customList(custom, "lod_shadow_bias", tonumber),
				lodFolded = customList(custom, "lod_folded"),
				lodFoldFrom = customNumber(custom, "lod_fold_from", 1e9),
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
	vertexShader = vertexShader or shaderSource("asset_shader.vert")
	fragmentShader = fragmentShader or shaderSource("asset_shader.frag")
	if not (vertexShader and fragmentShader) then
		return false
	end
	shader = gl.CreateShader({
		vertex = vertexShader,
		-- The shader has its environment map behind `IBL`: only a compiler that gives the
		-- samplers their units before validating, as `uniformInt` does here, may define it.
		-- Spliced in after the `#version` line, which has to stay first; `definitions` would
		-- go in front of it.
		fragment = params.ibl and fragmentShader:gsub("\n", "\n#define IBL 1\n", 1)
			or fragmentShader,
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
			envMap = ENVIRONMENT_TEXUNIT,
		},
	})

	if not shader then
		Spring.Echo("[sb-asset-shader] compile failed: " .. tostring(gl.GetShaderLog()))
		return false
	end

	uniforms = {}
	if params.chatty then
		Spring.Echo("[sb-asset-shader] compiled")
	end
	return true
end


--- The `sb_asset_lod_tint` debug view's colour per level.
local LOD_TINTS = { { 1, 1, 1 }, { 0.4, 1, 0.4 }, { 1, 1, 0.3 }, { 1, 0.35, 0.35 } }

--- Draws nothing: the piece list a level gives the pieces it does not draw.
local emptyList

--- Levels of detail. `lod_pieces` names one hull piece per level, the full hull first
--- (`shipassets/lod.py`); a level draws its own hull and hides every other level's, and the moving
--- pieces (the gun, the rotor) draw too, except from level `lod_fold_from` on, where they are part
--- of the level's own hull. Level N+1 is drawn from `lod_distances`[N] on: elmos at a 45 degree
--- field of view, which the engine rescales for the view. Each level's `lod_occlusion` and
--- `lod_shadow_bias` go to the shader. Pieces are found by name: the model
--- loader puts a root node of its own above the file's, so the full hull is not piece 1.
---
--- Shadows cast from the hull, never from a reduced level.
---
--- The engine picks the shadow pass's level from a distance that is always zero, so the shadow
--- pass always takes the lowest level -- the full hull. There used to be a proxy level below the
--- hull here, so that shadows came from a reduced mesh and cost less; what it actually did was
--- shadow the ship with geometry nobody was looking at. A plate that the hull does not have casts
--- a hard triangle across one the hull does, at every distance including point blank, which is
--- what `just lod-where`'s self-shadow column and a screenshot of the shield both showed.
---
--- `LODScale shadow` would let the shadow pass choose a farther level honestly, but in this
--- engine build it moves the view's choice with it (see the commit that removed it), so the
--- shadow pass gets the hull and the cost that comes with it.
---
--- Returns the engine's level count, and the real level (for per-level values) of each.
local function setupLevels(api, objectID, maps, isUnit)
	local levels = params.levels and #maps.lodPieces or 1
	if levels < 2 then
		api.SetLODCount(objectID, 1)
		return 1, { 1 }
	end
	local real = {}
	for level = 1, levels do
		real[#real + 1] = level
	end
	local count = #real
	api.SetLODCount(objectID, count)
	-- The engine searches down from a material's last level, which is level 1 unless set.
	api.SetMaterialLastLOD(objectID, "opaque", count)
	api.SetMaterialLastLOD(objectID, "shadow", count)
	emptyList = emptyList or gl.CreateList(function() end)
	local pieceMap = (isUnit and Spring.GetUnitPieceMap or Spring.GetFeaturePieceMap)(objectID) or {}
	local hulls = {}
	for level, name in ipairs(maps.lodPieces) do
		hulls[level] = pieceMap[name]
	end
	if params.chatty and not maps.levelsReported then
		maps.levelsReported = true
		local found = {}
		for level, name in ipairs(maps.lodPieces) do
			found[level] = ("%s=%s"):format(name, tostring(hulls[level]))
		end
		Spring.Echo(("[sb-asset-shader] %d levels of detail, pieces %s, forced %d"):format(
			levels, table.concat(found, ","), params.forcedLevel))
	end
	for engine = 1, count do
		local level = real[engine]
		if engine > 1 then
			local distance = maps.lodDistances[level - 1] or 1e9
			if params.forcedLevel > 0 then
				distance = level <= params.forcedLevel and 0 or 1e9
			end
			api.SetLODDistance(objectID, engine, distance)
		end
		for other = 1, levels do
			if other ~= level and hulls[other] then
				api.SetPieceList(objectID, engine, hulls[other], emptyList)
			end
		end
		if level >= maps.lodFoldFrom then
			for _, name in ipairs(maps.lodFolded) do
				if pieceMap[name] then
					api.SetPieceList(objectID, engine, pieceMap[name], emptyList)
				end
			end
		end
		api.SetMaterial(objectID, engine, "shadow", { shader = "S3O", usecamera = true, culling = GL.BACK })
	end
	return count, real
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

	local levels, realLevel = setupLevels(api, objectID, maps, isUnit)
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
	if params.ibl then
		texunits[ENVIRONMENT_TEXUNIT] = ENVIRONMENT_MAP
	end
	local material = {
		shader = shader,
		usecamera = true,
	}
	for unit, tex in pairs(texunits) do
		material["texunit" .. unit] = tex
	end
	-- Each level gets a material of its own, told apart by `order`. The engine keeps one set of
	-- uniforms per material and object (`LuaMaterial::Compare`, `LuaMatUniforms::GetObjectUniform`),
	-- not one per level: levels sharing a material share its uniforms, and the last value written
	-- wins for all of them. `order` only sorts the bins, so this costs nothing but the split.
	for level = 1, levels do
		local own = material
		if levels > 1 then
			own = { order = level - 1 }
			for key, value in pairs(material) do
				own[key] = value
			end
		end
		api.SetMaterial(objectID, level, "opaque", own)
	end
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
			for level = 1, levels do
				api.SetForwardMaterialUniform(objectID, "opaque", level, name, glType, value)
			end
		end
		for level = 1, levels do
			local function perLevel(name, glType, value)
				api.SetForwardMaterialUniform(objectID, "opaque", level, name, glType, value)
			end
			local real = realLevel[level]
			perLevel("lodTint", GL_FLOAT_VEC3,
				params.lodTint and LOD_TINTS[math.min(real, #LOD_TINTS)] or { 1, 1, 1 })
			perLevel("lodOcclusion", GL_FLOAT, { maps.lodOcclusion[real] or 1 })
			perLevel("lodShadowBias", GL_FLOAT, { maps.lodShadowBias[real] or 1 })
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
	if isUnit and params.chatty and not reportedUnit then
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
	if envelope.tag == "renderLab" and type(data) == "string" then
		return labCommand(data)
	end
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

--- The game's own renderer, when it is mounted: it dresses the ships itself and answers the
--- Rendering Lab, so this gadget stands down.
local GAME_RENDERER = "luarules/wasm/shipgame-look.wasm"

local labStart

local function labValue(control)
	local value = params[control.param]
	if control.min then
		return tonumber(value) or 0
	end
	return value and true or false
end

local function labState()
	local values = {}
	for _, control in ipairs(LAB_CONTROLS) do
		values[control.id] = labValue(control)
	end
	return {
		values = values,
		view = LAB_VIEWS[params.debugView + 1] or "final",
		overlays_on = {},
		solo = json.null,
		scene = json.null,
		lights = { candidates = 0, chosen = 0 },
	}
end

--- To LuaRules, not LuaUI: the native panel hears every rules message, and a game mounted as
--- a mutator may have replaced SpringBoard's LuaUI with its own.
local function labReply(reply)
	Spring.SendLuaRulesMsg(LAB_REPLY_PREFIX .. json.encode(reply))
end

local function labCapabilities()
	local controls = {}
	for _, control in ipairs(LAB_CONTROLS) do
		local kind = control.min and "number" or "switch"
		controls[#controls + 1] = {
			id = control.id, name = control.name, category = control.category, kind = kind,
			min = control.min or 0, max = control.max or 0,
			default = labValue(control), value = labValue(control),
			what = control.what, how = "Custom Unit Shaders gadget, `api_sb_asset_shader.lua`.",
			look = "", solo = false,
		}
	end
	local views = {}
	for index, id in ipairs(LAB_VIEWS) do
		views[index] = { id = id, name = LAB_VIEW_NAMES[index] }
	end
	local reply = labState()
	reply.kind = "capabilities"
	reply.controls = controls
	reply.categories = { { id = "material", name = "Material" }, { id = "lighting", name = "Lighting" } }
	reply.views = views
	reply.overlays = {}
	reply.scenes = {}
	return reply
end

--- One line from the Rendering Lab: see the game's `shipcore::lab::wire` for the words.
local function labCommand(line)
	local words = {}
	for word in line:gmatch("%S+") do
		words[#words + 1] = word
	end
	local verb = words[1]
	if verb == "list" then
		labStart = labStart or {}
		for _, control in ipairs(LAB_CONTROLS) do
			labStart[control.param] = params[control.param]
		end
		return labReply(labCapabilities())
	elseif verb == "set" then
		for _, control in ipairs(LAB_CONTROLS) do
			if control.id == words[2] then
				if control.min then
					params[control.param] = math.max(control.min, math.min(control.max, tonumber(words[3]) or 0))
				else
					params[control.param] = words[3] ~= "0" and words[3] ~= "false"
				end
			end
		end
		applyAll()
	elseif verb == "view" then
		for index, id in ipairs(LAB_VIEWS) do
			if id == words[2] then
				params.debugView = index - 1
			end
		end
	elseif verb == "reset" and labStart then
		for param, value in pairs(labStart) do
			params[param] = value
		end
		params.debugView = 0
		applyAll()
	end
	local reply = labState()
	reply.kind = "values"
	labReply(reply)
end

function gadget:Initialize()
	local gameRenderer = VFS.FileExists(GAME_RENDERER) or VFS.FileExists(GAME_RENDERER, VFS.ZIP)
	if not gl.CreateShader or not Spring.FeatureRendering or gameRenderer then
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
	gl.Uniform(uniformLocation("iblEnabled"), params.ibl and 1.0 or 0.0)
	gl.Uniform(uniformLocation("iblDiffuse"), params.iblDiffuse)
	gl.Uniform(uniformLocation("iblSpecular"), params.iblSpecular)
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
