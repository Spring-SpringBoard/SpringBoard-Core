//! Builds a map's `mapinfo.lua` from the live engine state (atmosphere,
//! lighting, water, sun, resources) plus the project's scenario/team info.

use serde_json::{json, Map, Value};
use spring_native::constants::GAME_SQUARE_SIZE;

use crate::sbc::command_system::context::Context;
use crate::sbc::project::ops::lua_writer;
use crate::sbc::project::{ProjectManager, ScenarioInfoManager};
use crate::sbc::teams::{Team, TeamManager};
use crate::sbc::textures::TextureModel;

const MAPINFO_EXTRA: &str = r#"
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- Helper

local function lowerkeys(ta)
    local fix = {}
    for i,v in pairs(ta) do
        if (type(i) == "string") then
            if (i ~= i:lower()) then
                fix[#fix+1] = i
            end
        end
        if (type(v) == "table") then
            lowerkeys(v)
        end
    end

    for i=1,#fix do
        local idx = fix[i]
        ta[idx:lower()] = ta[idx]
        ta[idx] = nil
    end
end

lowerkeys(mapInfo)

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- Map Options

if (Spring) then
    local function tmerge(t1, t2)
        for i,v in pairs(t2) do
            if (type(v) == "table") then
                t1[i] = t1[i] or {}
                tmerge(t1[i], v)
            else
                t1[i] = v
            end
        end
    end

    if (not Spring.GetMapOptions) then
        Spring.GetMapOptions = function() return {} end
    end
    function tobool(val)
        local t = type(val)
        if (t == 'nil') then
            return false
        elseif (t == 'boolean') then
            return val
        elseif (t == 'number') then
            return (val ~= 0)
        elseif (t == 'string') then
            return ((val ~= '0') and (val ~= 'false'))
        end
        return false
    end

    getfenv()["mapInfo"] = mapInfo
        local files = VFS.DirList("mapconfig/mapinfo/", "*.lua")
        table.sort(files)
        for i=1,#files do
            local newcfg = VFS.Include(files[i])
            if newcfg then
                lowerkeys(newcfg)
                tmerge(mapInfo, newcfg)
            end
        end
    getfenv()["mapInfo"] = nil
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

return mapInfo
"#;

pub(crate) fn export_text(ctx: &mut Context) -> String {
    lua_writer::mapinfo_file(&map_info(ctx), MAPINFO_EXTRA)
}

fn map_info(ctx: &mut Context) -> Value {
    let info = ctx.model::<ScenarioInfoManager>().serialize();
    let teams = ctx.model::<TeamManager>().all_teams();
    let project_name = ctx
        .model::<ProjectManager>()
        .name()
        .unwrap_or("")
        .to_string();
    json!({
        "name": info.name,
        "description": info.description,
        "version": info.version,
        "author": info.author,
        "mapfile": format!("maps/{project_name}.smf"),
        "shortname": "",
        "modtype": 3,
        "depend": ["Map Helper v1"],
        "replace": [],
        "voidWater": map_rendering_bool(ctx, "voidWater"),
        "voidGround": map_rendering_bool(ctx, "voidGround"),
        "atmosphere": atmosphere(ctx),
        "grass": {},
        "lighting": lighting(ctx),
        "water": water(ctx),
        "teams": teams_map(ctx, &teams),
        "terrainTypes": {},
        "custom": {},
        "smf": smf(ctx, &project_name),
        "resources": resources(ctx),
    })
}

fn atmosphere(ctx: &Context) -> Value {
    json!({
        "fogStart": atmosphere_scalar(ctx, "fogStart"),
        "fogEnd": atmosphere_scalar(ctx, "fogEnd"),
        "fogColor": atmosphere_vec(ctx, "fogColor"),
        "skyBox": "",
        "skyColor": atmosphere_vec(ctx, "skyColor"),
        "sunColor": atmosphere_vec(ctx, "sunColor"),
        "cloudColor": atmosphere_vec(ctx, "cloudColor"),
    })
}

fn lighting(ctx: &Context) -> Value {
    json!({
        "sunDir": sun_vec(ctx, "dir", ""),
        "groundAmbientColor": sun_vec(ctx, "ambient", ""),
        "groundDiffuseColor": sun_vec(ctx, "diffuse", ""),
        "groundSpecularColor": sun_vec(ctx, "specular", ""),
        "groundShadowDensity": sun_scalar(ctx, "shadowDensity", ""),
        "unitAmbientColor": sun_vec(ctx, "ambient", "unit"),
        "unitDiffuseColor": sun_vec(ctx, "diffuse", "unit"),
        "unitSpecularColor": sun_vec(ctx, "specular", "unit"),
        "unitShadowDensity": sun_scalar(ctx, "shadowDensity", "unit"),
    })
}

fn water(ctx: &Context) -> Value {
    json!({
        "repeatX": water_scalar(ctx, "repeatX"),
        "repeatY": water_scalar(ctx, "repeatY"),
        "ambientFactor": water_scalar(ctx, "ambientFactor"),
        "diffuseFactor": water_scalar(ctx, "diffuseFactor"),
        "specularFactor": water_scalar(ctx, "specularFactor"),
        "specularPower": water_scalar(ctx, "specularPower"),
        "planeColor": water_vec(ctx, "planeColor"),
        "hasWaterPlane": water_bool(ctx, "hasWaterPlane"),
        "diffuseColor": water_vec(ctx, "diffuseColor"),
        "specularColor": water_vec(ctx, "specularColor"),
        "fresnelMin": water_scalar(ctx, "fresnelMin"),
        "fresnelMax": water_scalar(ctx, "fresnelMax"),
        "fresnelPower": water_scalar(ctx, "fresnelPower"),
        "reflectionDistortion": water_scalar(ctx, "reflectionDistortion"),
        "blurBase": water_scalar(ctx, "blurBase"),
        "blurExponent": water_scalar(ctx, "blurExponent"),
        "perlinStartFreq": water_scalar(ctx, "perlinStartFreq"),
        "perlinLacunarity": water_scalar(ctx, "perlinLacunarity"),
        "perlinAmplitude": water_scalar(ctx, "perlinAmplitude"),
        "texture": water_texture(ctx, "texture"),
        "foamTexture": water_texture(ctx, "foamTexture"),
        "normalTexture": water_texture(ctx, "normalTexture"),
        "shoreWaves": water_bool(ctx, "shoreWaves"),
        "forceRendering": water_bool(ctx, "forceRendering"),
        "numTiles": water_scalar(ctx, "numTiles"),
    })
}

fn teams_map(ctx: &Context, teams: &[Team]) -> Value {
    let (map_x, map_z) = map_size(ctx).unwrap_or((0, 0));
    let mut out = Map::new();
    for (i, team) in teams.iter().enumerate() {
        let start = team.extra.get("startPos").and_then(Value::as_object);
        let x = start
            .and_then(|s| s.get("x"))
            .and_then(Value::as_f64)
            .unwrap_or(map_x as f64 / 2.0);
        let z = start
            .and_then(|s| s.get("z"))
            .and_then(Value::as_f64)
            .unwrap_or(map_z as f64 / 2.0);
        out.insert(i.to_string(), json!({ "startPos": { "x": x, "z": z } }));
    }
    Value::Object(out)
}

fn smf(ctx: &Context, project_name: &str) -> Value {
    let (minheight, maxheight) = ground_extremes(ctx).unwrap_or((0.0, 0.0));
    json!({
        "minheight": minheight,
        "maxheight": maxheight,
        "smtFileName0": format!("maps/{project_name}.smt"),
        "grassmapTex": "maps/grass.png",
    })
}

fn resources(ctx: &mut Context) -> Value {
    let mut out = Map::new();
    out.insert(
        "splatDetailNormalDiffuseAlpha".to_string(),
        Value::Bool(map_rendering_bool(ctx, "splatDetailNormalDiffuseAlpha")),
    );
    let textures = ctx.model::<TextureModel>().shading.textures();
    for tex in textures {
        if let Some(mapinfo_name) = shading_mapinfo_name(&tex.name) {
            out.insert(
                mapinfo_name.to_string(),
                Value::String(format!("maps/{}.png", tex.name)),
            );
        }
    }
    Value::Object(out)
}

fn shading_mapinfo_name(name: &str) -> Option<&'static str> {
    match name {
        "specular" => Some("specularTex"),
        "emission" => Some("lightEmissionTex"),
        "refl" => Some("skyReflectModTex"),
        "splat_distr" => Some("splatDistrTex"),
        "splat_normals0" => Some("splatDetailNormalTex0"),
        "splat_normals1" => Some("splatDetailNormalTex1"),
        "splat_normals2" => Some("splatDetailNormalTex2"),
        "splat_normals3" => Some("splatDetailNormalTex3"),
        "detail" => Some("detailTex"),
        _ => None,
    }
}

fn atmosphere_vec(ctx: &Context, key: &str) -> Value {
    ctx.interface
        .gfx()
        .get_atmosphere(key, "")
        .ok()
        .map(|(v, count, ..)| vec_value(&v, count))
        .unwrap_or_else(|| Value::Array(Vec::new()))
}

fn atmosphere_scalar(ctx: &Context, key: &str) -> f32 {
    ctx.interface
        .gfx()
        .get_atmosphere(key, "")
        .ok()
        .map(|(v, ..)| v[0])
        .unwrap_or(0.0)
}

fn sun_vec(ctx: &Context, key: &str, mode: &str) -> Value {
    ctx.interface
        .gfx()
        .get_sun(key, mode)
        .ok()
        .map(|(v, count, ..)| vec_value(&v, count))
        .unwrap_or_else(|| Value::Array(Vec::new()))
}

fn sun_scalar(ctx: &Context, key: &str, mode: &str) -> f32 {
    ctx.interface
        .gfx()
        .get_sun(key, mode)
        .ok()
        .map(|(v, ..)| v[0])
        .unwrap_or(0.0)
}

fn water_vec(ctx: &Context, key: &str) -> Value {
    ctx.interface
        .gfx()
        .get_water_rendering(key, "")
        .ok()
        .map(|(v, count, ..)| vec_value(&v, count))
        .unwrap_or_else(|| Value::Array(Vec::new()))
}

fn water_scalar(ctx: &Context, key: &str) -> f32 {
    ctx.interface
        .gfx()
        .get_water_rendering(key, "")
        .ok()
        .map(|(v, ..)| v[0])
        .unwrap_or(0.0)
}

fn water_bool(ctx: &Context, key: &str) -> bool {
    water_scalar(ctx, key) != 0.0
}

fn water_texture(ctx: &Context, key: &str) -> String {
    ctx.interface
        .unsynced_ctrl()
        .get_water_texture(key)
        .ok()
        .flatten()
        .unwrap_or_default()
}

fn map_rendering_bool(ctx: &Context, key: &str) -> bool {
    ctx.interface
        .gfx()
        .get_map_rendering(key, "")
        .ok()
        .map(|(v, ..)| v[0] != 0.0)
        .unwrap_or(false)
}

fn vec_value(values: &[f32; 4], count: u32) -> Value {
    Value::Array(
        values
            .iter()
            .take(count as usize)
            .copied()
            .map(Value::from)
            .collect(),
    )
}

fn ground_extremes(ctx: &Context) -> Option<(f32, f32)> {
    let (map_x, map_z) = map_size(ctx)?;
    let terrain = ctx.interface.terrain();
    let mut min_h = f32::INFINITY;
    let mut max_h = f32::NEG_INFINITY;
    for z in (0..=map_z).step_by(GAME_SQUARE_SIZE as usize) {
        for x in (0..=map_x).step_by(GAME_SQUARE_SIZE as usize) {
            let h = terrain.get_ground_height(x as f32, z as f32).unwrap_or(0.0);
            min_h = min_h.min(h);
            max_h = max_h.max(h);
        }
    }
    Some((min_h, max_h))
}

fn map_size(ctx: &Context) -> Option<(i32, i32)> {
    if let Some((map_x, map_z)) = crate::sbc::heightmap::ops::read::world_size(ctx.interface) {
        return Some((i32::try_from(map_x).ok()?, i32::try_from(map_z).ok()?));
    }

    let (square_size, squares_x, squares_z) =
        ctx.interface.vfs().get_map_square_texture_info().ok()?;
    (square_size > 0 && squares_x > 0 && squares_z > 0)
        .then_some((square_size * squares_x, square_size * squares_z))
}
