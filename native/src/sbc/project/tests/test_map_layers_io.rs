use std::time::Duration;

use crate::sbc::sbc::SBC;
use crate::sbc::tests::tests_api::TestCtx;

fn ground_height(sbc: &SBC, x: f32, z: f32) -> f32 {
    sbc.interface()
        .terrain()
        .get_ground_height(x, z)
        .unwrap_or(f32::MIN)
}

/// `SaveCommand` then `LoadProjectCommand` restores every map layer (heightmap,
/// grass, metal).
fn map_layers_project_save_load_roundtrip(ctx: &mut TestCtx) -> Result<(), String> {
    let root = std::env::temp_dir().join("sbc_map_layers_roundtrip.sdd");
    let project_files = root.join("sb_project_files");
    let heightmap_data = project_files.join("heightmap.data");
    let grass_data = project_files.join("grass.data");
    let metal_data = project_files.join("metal.data");
    let _ = std::fs::remove_dir_all(&root);

    let (sample_x, sample_z) = (0.0_f32, 0.0_f32);
    let height_value = 137.0_f32;

    {
        let synced = ctx.sbc.interface().synced_ctrl();
        let terrain = synced.terrain();
        let _ = terrain.set_height_map(sample_x, sample_z, height_value, 1.0);
        let _ = terrain.add_grass(sample_x, sample_z);
    }
    ctx.sbc
        .interface()
        .metal_map()
        .set_metal_amount(0, 0, 5.1)
        .map_err(|e| format!("set source metal: {e:?}"))?;

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

    // Wipe every layer so a successful load has to restore them.
    {
        let synced = ctx.sbc.interface().synced_ctrl();
        let terrain = synced.terrain();
        let _ = terrain.set_height_map(sample_x, sample_z, 0.0, 1.0);
        let _ = terrain.remove_grass(sample_x, sample_z);
    }
    ctx.sbc
        .interface()
        .metal_map()
        .set_metal_amount(0, 0, 0.0)
        .map_err(|e| format!("mutate metal after save: {e:?}"))?;

    ctx.route_command(serde_json::json!({
        "className": "LoadProjectCommand",
        "path": root.to_string_lossy()
    }));
    let restored = ctx.wait_for_io(Duration::from_secs(5), |sbc| {
        let height_ok = (ground_height(sbc, sample_x, sample_z) - height_value).abs() < 1.0;
        let grass_ok = sbc
            .interface()
            .terrain()
            .get_grass(sample_x, sample_z)
            .is_ok_and(|g| g > 0.0);
        let metal_ok = sbc
            .interface()
            .metal_map()
            .get_metal_amount(0, 0)
            .is_ok_and(|m| (m - 5.1).abs() < 0.001);
        height_ok && grass_ok && metal_ok
    });
    let _ = std::fs::remove_dir_all(&root);
    if !restored {
        return Err(format!(
            "LoadProjectCommand did not restore all layers: height {}, grass {:?}, metal {:?}",
            ground_height(ctx.sbc, sample_x, sample_z),
            ctx.sbc.interface().terrain().get_grass(sample_x, sample_z),
            ctx.sbc.interface().metal_map().get_metal_amount(0, 0),
        ));
    }
    Ok(())
}

crate::integration_test!(
    "map_layers_project_save_load_roundtrip",
    map_layers_project_save_load_roundtrip
);
