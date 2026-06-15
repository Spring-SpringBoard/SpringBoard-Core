use super::test_support::{register_full_brush, SQUARE_SIZE};
use crate::sbc::tests::tests_api::TestCtx;

fn terrain_grass_brush(ctx: &mut TestCtx) -> Result<(), String> {
    let (sx, _) = register_full_brush(ctx, "grass_brush");

    let click = 256.0_f32;
    let sample_x = 128.0_f32;
    let sample_z = 128.0_f32;
    clear_grass(ctx, sample_x, sample_z, 192.0);

    let before = grass_at(ctx, sample_x, sample_z)?;
    if before > 0.0 {
        return Err(format!("grass setup failed: sample starts at {before}"));
    }

    ctx.route_command(serde_json::json!({
        "className": "TerrainGrassCommand",
        "opts": {
            "x": click, "z": click,
            "size": (sx - 1) as f32 * SQUARE_SIZE,
            "rotation": 0.0,
            "shapeName": "grass_brush",
            "amount": 1.0
        }
    }));

    let after = grass_at(ctx, sample_x, sample_z)?;
    if after <= 0.0 {
        return Err(format!("grass brush did not add grass: sample={after}"));
    }

    ctx.route_command(serde_json::json!({ "className": "UndoCommand" }));
    let undone = grass_at(ctx, sample_x, sample_z)?;
    if undone > 0.0 {
        return Err(format!("undo did not remove grass: sample={undone}"));
    }
    Ok(())
}

fn clear_grass(ctx: &mut TestCtx, cx: f32, cz: f32, reach: f32) {
    let synced = ctx.sbc.interface().synced_ctrl();
    let terrain = synced.terrain();
    let mut x = cx - reach;
    while x <= cx + reach {
        let mut z = cz - reach;
        while z <= cz + reach {
            let _ = terrain.remove_grass(x, z);
            z += SQUARE_SIZE * 4.0;
        }
        x += SQUARE_SIZE * 4.0;
    }
}

fn grass_at(ctx: &mut TestCtx, x: f32, z: f32) -> Result<f32, String> {
    ctx.sbc
        .interface()
        .terrain()
        .get_grass(x, z)
        .map_err(|e| format!("get_grass: {e:?}"))
}

crate::integration_test!("terrain_grass_brush", terrain_grass_brush);
