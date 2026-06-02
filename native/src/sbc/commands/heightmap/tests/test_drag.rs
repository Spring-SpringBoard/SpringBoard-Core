use super::test_support::{
    ground_height, register_full_brush, seed_flat, SQUARE_SIZE,
};
use crate::sbc::tests::tests_api::{IntegrationTest, TestCtx};

fn terrain_drag_stroke(ctx: &mut TestCtx) -> Result<(), String> {
    let (sx, _) = register_full_brush(ctx, "drag_brush");

    let cx = 128.0_f32;
    let cz = 128.0_f32;
    let baseline = 50.0_f32;
    seed_flat(ctx, cx, cz, (sx as f32) * SQUARE_SIZE, baseline);

    let before = ground_height(ctx, cx, cz, "before")?;

    let set_mode = |ctx: &mut TestCtx, on: bool| {
        ctx.sbc.route(
            &serde_json::json!({
                "tag": "command",
                "data": { "className": "SetMultipleCommandModeCommand", "state": on }
            })
            .to_string(),
        );
    };
    let stamp = |ctx: &mut TestCtx| {
        ctx.sbc.route(
            &serde_json::json!({
                "tag": "command",
                "data": {
                    "className": "TerrainShapeModifyCommand",
                    "opts": {
                        "x": 256.0, "z": 256.0,
                        "size": (sx - 1) as f32 * SQUARE_SIZE,
                        "rotation": 0.0,
                        "strength": 100.0,
                        "shapeName": "drag_brush"
                    }
                }
            })
            .to_string(),
        );
    };

    set_mode(ctx, true);
    stamp(ctx);
    stamp(ctx);
    set_mode(ctx, false);

    let after = ground_height(ctx, cx, cz, "after stroke")?;
    if after <= before + 1.0 {
        return Err(format!(
            "drag stroke didn't raise centre: before {before}, after {after}"
        ));
    }

    ctx.sbc.route(
        &serde_json::json!({ "tag": "command", "data": { "className": "UndoCommand" } })
            .to_string(),
    );
    let undone = ground_height(ctx, cx, cz, "after undo")?;
    if (undone - before).abs() > 1.0 {
        return Err(format!(
            "one undo didn't revert the whole stroke: baseline {before}, after undo {undone}"
        ));
    }
    Ok(())
}

inventory::submit! {
    IntegrationTest { name: "terrain_drag_stroke", run: terrain_drag_stroke }
}
