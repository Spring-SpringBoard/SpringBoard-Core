use super::test_support::{
    ground_height, min_normal_y_across, register_full_brush, seed_flat, SQUARE_SIZE,
};
use crate::sbc::tests::tests_api::{IntegrationTest, TestCtx};

fn terrain_shape_brush(ctx: &mut TestCtx) -> Result<(), String> {
    let (sx, _) = register_full_brush(ctx, "shape_brush");

    let click = 256.0_f32;
    let cx = 128.0_f32;
    let cz = 128.0_f32;
    let baseline = 50.0_f32;
    seed_flat(ctx, cx, cz, (sx as f32) * SQUARE_SIZE, baseline);

    let before = ground_height(ctx, cx, cz, "before")?;

    ctx.sbc.route(
        &serde_json::json!({
            "tag": "command",
            "data": {
                "className": "TerrainShapeModifyCommand",
                "opts": {
                    "x": click, "z": click,
                    "size": (sx - 1) as f32 * SQUARE_SIZE,
                    "rotation": 0.0,
                    "strength": 100.0,
                    "shapeName": "shape_brush"
                }
            }
        })
        .to_string(),
    );

    let after = ground_height(ctx, cx, cz, "after")?;
    if after <= before + 1.0 {
        return Err(format!(
            "shape brush didn't raise centre: before {before}, after {after}"
        ));
    }

    let worst = min_normal_y_across(ctx, cx, cz, 160.0)?;
    if worst > 0.999 {
        return Err(format!(
            "shape brush changed heights but surface never recalc'd \
             (min normal.y={worst} across stamp, still flat)"
        ));
    }

    ctx.sbc.route(
        &serde_json::json!({ "tag": "command", "data": { "className": "UndoCommand" } })
            .to_string(),
    );
    let undone = ground_height(ctx, cx, cz, "after undo")?;
    if (undone - before).abs() > 1.0 {
        return Err(format!(
            "undo didn't restore centre height: baseline {before}, after undo {undone}"
        ));
    }
    let undone_worst = min_normal_y_across(ctx, cx, cz, 160.0)?;
    if undone_worst < 0.999 {
        return Err(format!(
            "undo restored heights but surface stayed tilted (min normal.y={undone_worst})"
        ));
    }
    Ok(())
}

inventory::submit! {
    IntegrationTest { name: "terrain_shape_brush", run: terrain_shape_brush }
}
