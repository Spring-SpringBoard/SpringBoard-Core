use super::test_support::{
    ground_height, min_normal_y_across, register_full_brush, seed_flat, SQUARE_SIZE,
};
use crate::sbc::tests::tests_api::TestCtx;

fn terrain_level_brush(ctx: &mut TestCtx) -> Result<(), String> {
    let (sx, _) = register_full_brush(ctx, "level_brush");

    let click = 256.0_f32;
    let cx = 128.0_f32;
    let cz = 128.0_f32;
    let baseline = 10.0_f32;
    seed_flat(ctx, cx, cz, (sx as f32) * SQUARE_SIZE, baseline);

    let target = 123.0_f32;
    let before = ground_height(ctx, cx, cz, "before")?;

    ctx.route_command(serde_json::json!({
        "className": "TerrainLevelCommand",
        "opts": {
            "x": click, "z": click,
            "size": (sx - 1) as f32 * SQUARE_SIZE,
            "rotation": 0.0,
            "strength": 1000.0,
            "shapeName": "level_brush",
            "height": target,
            "applyDirID": 1
        }
    }));

    let after = ground_height(ctx, cx, cz, "after")?;
    if !(after > before + 10.0 && after <= target + 1.0) {
        return Err(format!(
            "level brush didn't raise centre toward {target}: before {before}, after {after}"
        ));
    }

    let worst = min_normal_y_across(ctx, cx, cz, 160.0)?;
    if worst > 0.999 {
        return Err(format!(
            "level brush changed heights but surface never recalc'd \
             (min normal.y={worst} across stamp, still flat)"
        ));
    }
    Ok(())
}

crate::integration_test!("terrain_level_brush", terrain_level_brush);
