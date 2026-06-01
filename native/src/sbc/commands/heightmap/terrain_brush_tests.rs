use crate::sbc::tests::tests_api::{IntegrationTest, TestCtx};

const SQUARE_SIZE: f32 = 8.0;

fn terrain_level_brush(ctx: &mut TestCtx) -> Result<(), String> {
    let (sx, sz) = (33usize, 33usize);
    let mut res = serde_json::Map::new();
    for i in 0..(sx * sz) {
        res.insert(i.to_string(), serde_json::json!(1.0));
    }
    ctx.sbc.route(
        &serde_json::json!({
            "tag": "command",
            "data": {
                "className": "SetHeightmapBrushCommand",
                "greyscale": { "res": res, "sizeX": sx, "sizeZ": sz, "name": "test_brush" }
            }
        })
        .to_string(),
    );

    // SBC brush stamps span [x - size, x], so the click x is the stamp's far
    // edge and the centre lands at x - size/2. With x=256, size=256 the centre
    // is at world (128,128) — sample there.
    let click = 256.0_f32;
    let cx = 128.0_f32;
    let cz = 128.0_f32;
    let baseline = 10.0_f32;
    seed_flat(ctx, cx, cz, (sx as f32) * SQUARE_SIZE, baseline);

    let target = 123.0_f32;
    let before = ctx
        .sbc
        .interface()
        .terrain()
        .get_ground_height(cx, cz)
        .map_err(|e| format!("get_ground_height before: {e:?}"))?;

    ctx.sbc.route(
        &serde_json::json!({
            "tag": "command",
            "data": {
                "className": "TerrainLevelCommand",
                "opts": {
                    "x": click, "z": click,
                    "size": (sx - 1) as f32 * SQUARE_SIZE,
                    "rotation": 0.0,
                    "strength": 1000.0,
                    "shapeName": "test_brush",
                    "height": target,
                    "applyDirID": 1
                }
            }
        })
        .to_string(),
    );

    let after = ctx
        .sbc
        .interface()
        .terrain()
        .get_ground_height(cx, cz)
        .map_err(|e| format!("get_ground_height after: {e:?}"))?;

    if !(after > before + 10.0 && after <= target + 1.0) {
        return Err(format!(
            "level brush didn't raise centre toward {target}: before {before}, after {after}"
        ));
    }

    // Recalc gate (see min_normal_y_across): the levelled region rises out of
    // the flat baseline, tilting the slope at its rim. Without RecalcArea the
    // normal stays vertical everywhere even though heights moved.
    let worst = min_normal_y_across(ctx, cx, cz, 160.0)?;
    if worst > 0.999 {
        return Err(format!(
            "level brush changed heights but surface never recalc'd \
             (min normal.y={worst} across stamp, still flat) — RecalcArea not triggered."
        ));
    }
    Ok(())
}

/// The raise/lower brush (`TerrainShapeModifyCommand`, which uses the relative
/// `add_height_map`). Sets a flat baseline, stamps the brush with positive
/// strength, and checks the centre rose. This is the command the user reported
/// as "did nothing".
fn terrain_shape_brush(ctx: &mut TestCtx) -> Result<(), String> {
    let (sx, sz) = (33usize, 33usize);
    let mut res = serde_json::Map::new();
    for i in 0..(sx * sz) {
        res.insert(i.to_string(), serde_json::json!(1.0));
    }
    ctx.sbc.route(
        &serde_json::json!({
            "tag": "command",
            "data": {
                "className": "SetHeightmapBrushCommand",
                "greyscale": { "res": res, "sizeX": sx, "sizeZ": sz, "name": "shape_brush" }
            }
        })
        .to_string(),
    );

    let click = 256.0_f32;
    let cx = 128.0_f32;
    let cz = 128.0_f32;
    let baseline = 50.0_f32;
    seed_flat(ctx, cx, cz, (sx as f32) * SQUARE_SIZE, baseline);

    let before = ctx
        .sbc
        .interface()
        .terrain()
        .get_ground_height(cx, cz)
        .map_err(|e| format!("get_ground_height before: {e:?}"))?;

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

    let after = ctx
        .sbc
        .interface()
        .terrain()
        .get_ground_height(cx, cz)
        .map_err(|e| format!("get_ground_height after: {e:?}"))?;

    if after <= before + 1.0 {
        return Err(format!(
            "shape brush didn't raise centre: before {before}, after {after}"
        ));
    }

    // The data changed (above). Now the real gate: did the surface actually
    // recalc? The raised region tilts the slope at its rim, so the normal must
    // move off vertical somewhere across the stamp. With no recalc it stays ~1.0.
    let worst = min_normal_y_across(ctx, cx, cz, 160.0)?;
    if worst > 0.999 {
        return Err(format!(
            "shape brush changed heights but surface never recalc'd \
             (min normal.y={worst} across stamp, still flat) — RecalcArea not triggered. \
             Heights moved in data but not visually/in sim. See EditHeightMap binding."
        ));
    }

    // Undo (Rust's UndoCommand pops its undo stack and replays the brush
    // negated, inside its own set_height_map_func batch). Centre must return to
    // the baseline and the surface must re-flatten — proving undo reverses both
    // the data and the recalc, not just one.
    ctx.sbc.route(
        &serde_json::json!({ "tag": "command", "data": { "className": "UndoCommand" } })
            .to_string(),
    );
    let undone = ctx
        .sbc
        .interface()
        .terrain()
        .get_ground_height(cx, cz)
        .map_err(|e| format!("get_ground_height after undo: {e:?}"))?;
    if (undone - before).abs() > 1.0 {
        return Err(format!(
            "undo didn't restore centre height: baseline {before}, after undo {undone}"
        ));
    }
    let undone_worst = min_normal_y_across(ctx, cx, cz, 160.0)?;
    if undone_worst < 0.999 {
        return Err(format!(
            "undo restored heights but surface stayed tilted \
             (min normal.y={undone_worst}) — undo's recalc didn't run"
        ));
    }
    Ok(())
}

/// A brush drag stroke groups its stamps into one undo entry. Mirrors the Lua
/// drag path (`SetMultipleCommandModeCommand(true)` … stamps … `(false)`): in
/// streaming mode the manager buffers commands and collapses them into one
/// CompoundCommand on stop, so a single undo reverts the whole stroke. Exercises
/// the streaming start/stop lifecycle that the `already streaming / not
/// streaming` desync bug lived in.
fn terrain_drag_stroke(ctx: &mut TestCtx) -> Result<(), String> {
    let (sx, sz) = (33usize, 33usize);
    let mut res = serde_json::Map::new();
    for i in 0..(sx * sz) {
        res.insert(i.to_string(), serde_json::json!(1.0));
    }
    ctx.sbc.route(
        &serde_json::json!({
            "tag": "command",
            "data": {
                "className": "SetHeightmapBrushCommand",
                "greyscale": { "res": res, "sizeX": sx, "sizeZ": sz, "name": "drag_brush" }
            }
        })
        .to_string(),
    );

    let cx = 128.0_f32;
    let cz = 128.0_f32;
    let baseline = 50.0_f32;
    seed_flat(ctx, cx, cz, (sx as f32) * SQUARE_SIZE, baseline);

    let before = ctx
        .sbc
        .interface()
        .terrain()
        .get_ground_height(cx, cz)
        .map_err(|e| format!("get_ground_height before: {e:?}"))?;

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

    let after = ctx
        .sbc
        .interface()
        .terrain()
        .get_ground_height(cx, cz)
        .map_err(|e| format!("get_ground_height after stroke: {e:?}"))?;
    if after <= before + 1.0 {
        return Err(format!(
            "drag stroke didn't raise centre: before {before}, after {after}"
        ));
    }

    // A single undo must revert the WHOLE stroke (both stamps), proving they
    // collapsed into one undo entry — not just the last stamp.
    ctx.sbc.route(
        &serde_json::json!({ "tag": "command", "data": { "className": "UndoCommand" } })
            .to_string(),
    );
    let undone = ctx
        .sbc
        .interface()
        .terrain()
        .get_ground_height(cx, cz)
        .map_err(|e| format!("get_ground_height after undo: {e:?}"))?;
    if (undone - before).abs() > 1.0 {
        return Err(format!(
            "one undo didn't revert the whole stroke: baseline {before}, after undo {undone} \
             (stroke peak was {after}) — stamps didn't group into one undo entry"
        ));
    }
    Ok(())
}

/// Flatten the square region (`cx,cz` ± `reach`) to `height`, inside a
/// `set_height_map_func` batch so the engine recalcs it to a clean flat state
/// (heights *and* normals). Tests share one map, so each starts by resetting its
/// own region — otherwise a prior test's leftover terrain skews this one.
fn seed_flat(ctx: &mut TestCtx, cx: f32, cz: f32, reach: f32, height: f32) {
    let interface = ctx.sbc.interface();
    let synced = interface.synced_ctrl();
    let terrain = synced.terrain();
    let _ = terrain.set_height_map_func(|| {
        let mut x = cx - reach;
        while x <= cx + reach {
            let mut z = cz - reach;
            while z <= cz + reach {
                let _ = terrain.set_height_map(x, z, height, 1.0);
                z += SQUARE_SIZE;
            }
            x += SQUARE_SIZE;
        }
    });
}

/// Smallest `normal.y` over a band of points spanning the stamp (centre `cx,cz`,
/// half-width `reach`). A uniform brush raises a flat-topped region whose slope
/// lives only at the *rim*, so probing one interior point can miss it — scan the
/// whole band and take the most-tilted sample. A recalc'd stamp drops this well
/// below 1.0 at the rim; with no recalc every sample stays ~1.0.
fn min_normal_y_across(ctx: &mut TestCtx, cx: f32, cz: f32, reach: f32) -> Result<f32, String> {
    let mut worst = 1.0_f32;
    let mut x = cx - reach;
    while x <= cx + reach {
        let ny = ground_normal_y(ctx, x, cz)?;
        worst = worst.min(ny);
        x += SQUARE_SIZE;
    }
    Ok(worst)
}

/// The surface normal's `y` at a world point. Flat ground is ~1.0; the engine
/// recomputes it inside `RecalcArea` (`UpdateFaceNormals`), so it's the *recalc*
/// signal — distinct from `get_ground_height`, which reflects the corner-height
/// write regardless of recalc.
///
/// `smoothed=true` reads the face-normal map, which `RecalcArea` updates
/// immediately. `smoothed=false` reads the *smooth-mesh* normal, rebuilt by a
/// deferred `smoothGround.MapChanged` — that lags a synchronous read and would
/// give a stale answer right after a brush stamp/undo.
fn ground_normal_y(ctx: &mut TestCtx, x: f32, z: f32) -> Result<f32, String> {
    let (normal, _slope) = ctx
        .sbc
        .interface()
        .terrain()
        .get_ground_normal(x, z, true)
        .map_err(|e| format!("get_ground_normal: {e:?}"))?;
    Ok(normal.y)
}

inventory::submit! {
    IntegrationTest { name: "terrain_level_brush", run: terrain_level_brush }
}

inventory::submit! {
    IntegrationTest { name: "terrain_shape_brush", run: terrain_shape_brush }
}

inventory::submit! {
    IntegrationTest { name: "terrain_drag_stroke", run: terrain_drag_stroke }
}
