use std::time::Duration;

use crate::sbc::tests::tests_api::TestCtx;

/// `save_metal_map` writes one little-endian `f32` per metal-map cell, so the
/// file size must equal `metalMapSizeX * metalMapSizeZ * 4` bytes.
fn save_metal_map_file(ctx: &mut TestCtx) -> Result<(), String> {
    let (mmx, mmz) = ctx
        .sbc
        .interface()
        .metal_map()
        .get_metal_map_size()
        .map_err(|e| format!("get_metal_map_size: {e:?}"))?;
    let expected = (mmx as u64) * (mmz as u64) * 4;

    let path = std::env::temp_dir().join("sbc_metal_map.data");
    let _ = std::fs::remove_file(&path);

    ctx.route_message(
        "save_metal_map",
        serde_json::json!({ "path": path.to_string_lossy() }),
    );
    if !ctx.wait_for_file(&path, Duration::from_secs(5)) {
        return Err("save_metal_map did not write the file".to_string());
    }

    let size = std::fs::metadata(&path)
        .map_err(|e| format!("stat metal map: {e}"))?
        .len();
    let _ = std::fs::remove_file(&path);
    if size != expected {
        return Err(format!("metal map size = {size}, expected {expected}"));
    }
    Ok(())
}

/// `save_grass_map` writes one `u8` per grass cell, stepping the map by
/// `8 * 4` engine units in each axis.
fn save_grass_map_file(ctx: &mut TestCtx) -> Result<(), String> {
    const GRASS_STEP: i64 = 8 * 4;
    let (mmx, mmz) = ctx
        .sbc
        .interface()
        .metal_map()
        .get_metal_map_size()
        .map_err(|e| format!("get_metal_map_size: {e:?}"))?;
    // The grass handler derives map size the same way (`metalMapSize * 16`).
    let size_x = (mmx as i64) * 16;
    let size_z = (mmz as i64) * 16;
    let cols = (size_x + GRASS_STEP - 1) / GRASS_STEP;
    let rows = (size_z + GRASS_STEP - 1) / GRASS_STEP;
    let expected = (cols * rows) as u64;

    let path = std::env::temp_dir().join("sbc_grass_map.data");
    let _ = std::fs::remove_file(&path);

    ctx.route_message(
        "save_grass_map",
        serde_json::json!({ "path": path.to_string_lossy() }),
    );
    if !ctx.wait_for_file(&path, Duration::from_secs(5)) {
        return Err("save_grass_map did not write the file".to_string());
    }

    let size = std::fs::metadata(&path)
        .map_err(|e| format!("stat grass map: {e}"))?
        .len();
    let _ = std::fs::remove_file(&path);
    if size != expected {
        return Err(format!("grass map size = {size}, expected {expected}"));
    }
    Ok(())
}

crate::integration_test!("save_metal_map_file", save_metal_map_file);
crate::integration_test!("save_grass_map_file", save_grass_map_file);
