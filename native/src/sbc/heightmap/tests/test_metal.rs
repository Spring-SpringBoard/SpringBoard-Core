use super::test_support::{register_full_brush, SQUARE_SIZE};
use crate::sbc::tests::tests_api::TestCtx;

const METAL_RESOLUTION: i32 = 16;

fn terrain_metal_brush(ctx: &mut TestCtx) -> Result<(), String> {
    let (sx, _) = register_full_brush(ctx, "metal_brush");

    let click = 256.0_f32;
    let sample_x = 128.0_f32;
    let sample_z = 128.0_f32;
    set_metal(ctx, sample_x, sample_z, 0.0)?;

    let before = metal_at(ctx, sample_x, sample_z)?;
    if before != 0.0 {
        return Err(format!("metal setup failed: sample starts at {before}"));
    }

    ctx.route_command(serde_json::json!({
        "className": "TerrainMetalCommand",
        "opts": {
            "x": click, "z": click,
            "size": (sx - 1) as f32 * SQUARE_SIZE,
            "rotation": 0.0,
            "shapeName": "metal_brush",
            "amount": 3.0
        }
    }));

    let after = metal_at(ctx, sample_x, sample_z)?;
    if (after - 3.0).abs() > 0.01 {
        return Err(format!("metal brush expected 3.0, got {after}"));
    }

    ctx.route_command(serde_json::json!({ "className": "UndoCommand" }));
    let undone = metal_at(ctx, sample_x, sample_z)?;
    if undone.abs() > 0.01 {
        return Err(format!("undo did not restore metal: sample={undone}"));
    }
    Ok(())
}

fn set_metal(ctx: &mut TestCtx, x: f32, z: f32, value: f32) -> Result<(), String> {
    let rx = (x / METAL_RESOLUTION as f32).round() as i32;
    let rz = (z / METAL_RESOLUTION as f32).round() as i32;
    ctx.sbc
        .interface()
        .metal_map()
        .set_metal_amount(rx, rz, value)
        .map(|_| ())
        .map_err(|e| format!("set_metal_amount: {e:?}"))
}

fn metal_at(ctx: &mut TestCtx, x: f32, z: f32) -> Result<f32, String> {
    let rx = (x / METAL_RESOLUTION as f32).round() as i32;
    let rz = (z / METAL_RESOLUTION as f32).round() as i32;
    ctx.sbc
        .interface()
        .metal_map()
        .get_metal_amount(rx, rz)
        .map_err(|e| format!("get_metal_amount: {e:?}"))
}

crate::integration_test!("terrain_metal_brush", terrain_metal_brush);
