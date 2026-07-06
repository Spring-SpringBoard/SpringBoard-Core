use std::time::Duration;

use crate::sbc::sbc::SBC;
use crate::sbc::tests::tests_api::TestCtx;

const SQUARE_SIZE: f32 = 8.0;
const METAL_RESOLUTION: f32 = 16.0;

/// `SaveCommand` then `LoadProjectCommand` restores every map layer (heightmap,
/// grass, metal). Layers are painted through the real terrain brush commands so
/// the test exercises the same write path as the editor, not raw engine pokes.
fn map_layers_project_save_load_roundtrip(ctx: &mut TestCtx) -> Result<(), String> {
    let root = std::env::temp_dir().join("sbc_map_layers_roundtrip.sdd");
    let project_files = root.join("sb_project_files");
    let heightmap_data = project_files.join("heightmap.data");
    let grass_data = project_files.join("grass.data");
    let metal_data = project_files.join("metal.data");
    let _ = std::fs::remove_dir_all(&root);

    let brush = "map_layers_brush";
    let sx = register_brush(ctx, brush);
    let size = (sx - 1) as f32 * SQUARE_SIZE;
    let click = 256.0_f32;
    let (sample_x, sample_z) = (128.0_f32, 128.0_f32);

    // Paint every layer through the real commands, then capture what landed.
    paint_height(ctx, brush, click, size, 137.0);
    paint_grass(ctx, brush, click, size, 1.0);
    paint_metal(ctx, brush, click, size, 5.0);

    let painted_height = ground_height(ctx.sbc, sample_x, sample_z);
    let painted_metal = metal_at(ctx.sbc, sample_x, sample_z);
    if grass_at(ctx.sbc, sample_x, sample_z) <= 0.0 {
        return Err("grass brush did not add grass before save".to_string());
    }
    if painted_metal <= 0.0 {
        return Err(format!("metal brush did not paint metal: {painted_metal}"));
    }

    ctx.route_command(serde_json::json!({
        "className": "SaveCommand",
        "path": root.to_string_lossy(),
        "isNewProject": true
    }));
    for (file, label) in [
        (&heightmap_data, "heightmap.data"),
        (&grass_data, "grass.data"),
        (&metal_data, "metal.data"),
    ] {
        if !ctx.wait_for_file(file, Duration::from_secs(5)) {
            return Err(format!(
                "SaveCommand did not write sb_project_files/{label}"
            ));
        }
    }

    // Wipe every layer through the same commands so load has to restore them.
    paint_height(ctx, brush, click, size, 0.0);
    paint_grass(ctx, brush, click, size, 0.0);
    paint_metal(ctx, brush, click, size, 0.0);

    ctx.route_command(serde_json::json!({
        "className": "LoadProjectCommand",
        "path": root.to_string_lossy()
    }));
    let restored = ctx.wait_for_io(Duration::from_secs(5), |sbc| {
        let height_ok = (ground_height(sbc, sample_x, sample_z) - painted_height).abs() < 1.0;
        let grass_ok = grass_at(sbc, sample_x, sample_z) > 0.0;
        let metal_ok = (metal_at(sbc, sample_x, sample_z) - painted_metal).abs() < 0.01;
        height_ok && grass_ok && metal_ok
    });
    let _ = std::fs::remove_dir_all(&root);
    if !restored {
        return Err(format!(
            "LoadProjectCommand did not restore all layers: height {} (want {painted_height}), \
             grass {}, metal {} (want {painted_metal})",
            ground_height(ctx.sbc, sample_x, sample_z),
            grass_at(ctx.sbc, sample_x, sample_z),
            metal_at(ctx.sbc, sample_x, sample_z),
        ));
    }
    Ok(())
}

/// Register a full-strength square brush so the terrain commands have a shape.
fn register_brush(ctx: &mut TestCtx, name: &str) -> usize {
    let (sx, sz) = (33usize, 33usize);
    let mut res = serde_json::Map::new();
    for i in 0..(sx * sz) {
        res.insert(i.to_string(), serde_json::json!(1.0));
    }
    ctx.route_command(serde_json::json!({
        "className": "SetHeightmapBrushCommand",
        "greyscale": { "res": res, "sizeX": sx, "sizeZ": sz, "name": name }
    }));
    sx
}

fn paint_height(ctx: &mut TestCtx, brush: &str, click: f32, size: f32, height: f32) {
    ctx.route_command(serde_json::json!({
        "className": "TerrainLevelCommand",
        "opts": {
            "x": click, "z": click, "size": size, "rotation": 0.0,
            "strength": 1000.0, "shapeName": brush, "height": height, "applyDirID": 1
        }
    }));
}

fn paint_grass(ctx: &mut TestCtx, brush: &str, click: f32, size: f32, amount: f32) {
    ctx.route_command(serde_json::json!({
        "className": "TerrainGrassCommand",
        "opts": {
            "x": click, "z": click, "size": size, "rotation": 0.0,
            "shapeName": brush, "amount": amount
        }
    }));
}

fn paint_metal(ctx: &mut TestCtx, brush: &str, click: f32, size: f32, amount: f32) {
    ctx.route_command(serde_json::json!({
        "className": "TerrainMetalCommand",
        "opts": {
            "x": click, "z": click, "size": size, "rotation": 0.0,
            "shapeName": brush, "amount": amount
        }
    }));
}

fn ground_height(sbc: &SBC, x: f32, z: f32) -> f32 {
    sbc.interface()
        .terrain()
        .get_ground_height(x, z)
        .unwrap_or(f32::MIN)
}

fn grass_at(sbc: &SBC, x: f32, z: f32) -> f32 {
    sbc.interface().terrain().get_grass(x, z).unwrap_or(0.0)
}

fn metal_at(sbc: &SBC, x: f32, z: f32) -> f32 {
    let rx = (x / METAL_RESOLUTION).round() as i32;
    let rz = (z / METAL_RESOLUTION).round() as i32;
    sbc.interface()
        .metal_map()
        .get_metal_amount(rx, rz)
        .unwrap_or(f32::MIN)
}

crate::integration_test!(
    "map_layers_project_save_load_roundtrip",
    map_layers_project_save_load_roundtrip
);
