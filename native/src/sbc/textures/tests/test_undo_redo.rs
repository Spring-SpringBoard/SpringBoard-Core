//! The native undo/redo machinery: the copy-on-write swap stacks, multi-level
//! ladders, history fork, clear, and the full command-routed stroke.
//!
//! Tests share one engine boot, so each starts from a known slate
//! (`clear_undo_redo` or a `push_stack` to close leftovers) and asserts deltas.

use super::test_support::{
    approx_eq, artifact_dir, back_up_region, buffers_differ, fill, fill_stroke, generate,
    make_filled_texture, read_first_pixel, read_pixel, read_texture_rgba, save_texture_png,
};
use crate::sbc::tests::tests_api::TestCtx;
use crate::sbc::textures::TextureModel;

fn route(ctx: &mut TestCtx, data: serde_json::Value) {
    ctx.route_command(data);
}

/// Atlas tile backup, paint, push, and pop restores the prior pixels.
fn texture_model_undo(ctx: &mut TestCtx) -> Result<(), String> {
    generate(ctx);

    let region = back_up_region(ctx, 0.0, 0.0, 0.0, 0.0);
    let tile_name = region
        .first()
        .ok_or("no map tiles generated")?
        .texture
        .clone();

    // Close that first (incidental) backup, then set a clean baseline.
    ctx.sbc.model::<TextureModel>().history.push_stack(None);
    ctx.sbc.model::<TextureModel>().history.pop_stack(None);
    fill(ctx, &tile_name, [0.0, 0.0, 1.0, 1.0]);

    let _ = back_up_region(ctx, 0.0, 0.0, 0.0, 0.0);
    fill(ctx, &tile_name, [1.0, 0.0, 0.0, 1.0]);
    ctx.sbc.model::<TextureModel>().history.push_stack(None);

    let after_paint = read_first_pixel(ctx, &tile_name).ok_or("read after paint failed")?;
    if !(after_paint.0 > 0.5 && after_paint.2 < 0.5) {
        return Err(format!("tile not red after paint: {after_paint:?}"));
    }

    ctx.sbc.model::<TextureModel>().history.pop_stack(None);
    let after_undo = read_first_pixel(ctx, &tile_name).ok_or("read after undo failed")?;
    if !(after_undo.2 > 0.5 && after_undo.0 < 0.5) {
        return Err(format!(
            "tile not restored to blue after undo: {after_undo:?}"
        ));
    }
    Ok(())
}

/// Three stacked strokes, undo all the way down then redo all the way up,
/// pixel-checked at every rung. Catches a swap that only round-trips one level.
fn texture_undo_redo_ladder(ctx: &mut TestCtx) -> Result<(), String> {
    generate(ctx);
    ctx.sbc.model::<TextureModel>().history.clear();
    let tile = ctx
        .sbc
        .model::<TextureModel>()
        .tiles
        .texture(0, 0)
        .ok_or("no tile (0,0)")?;

    fill(ctx, &tile, [0.0, 0.0, 1.0, 1.0]);
    let b0 = read_first_pixel(ctx, &tile).ok_or("read baseline")?;

    let p1 = fill_stroke(ctx, &tile, [1.0, 0.0, 0.0, 1.0]);
    let p2 = fill_stroke(ctx, &tile, [0.0, 1.0, 0.0, 1.0]);
    let p3 = fill_stroke(ctx, &tile, [1.0, 1.0, 1.0, 1.0]);

    if ctx.sbc.model::<TextureModel>().history.undo_depth() != 3 {
        return Err(format!(
            "expected 3 undo groups, got {}",
            ctx.sbc.model::<TextureModel>().history.undo_depth()
        ));
    }
    if approx_eq(p1, p2) || approx_eq(p2, p3) || approx_eq(p1, b0) {
        return Err(format!(
            "stroke colours not distinct: b0={b0:?} p1={p1:?} p2={p2:?} p3={p3:?}"
        ));
    }

    for (label, want) in [("undo3", p2), ("undo2", p1), ("undo1", b0)] {
        ctx.sbc.model::<TextureModel>().history.pop_stack(None);
        let got = read_first_pixel(ctx, &tile).ok_or("read during undo")?;
        if !approx_eq(got, want) {
            return Err(format!("{label}: tile {got:?}, expected {want:?}"));
        }
    }
    if ctx.sbc.model::<TextureModel>().history.undo_depth() != 0
        || ctx.sbc.model::<TextureModel>().history.redo_depth() != 3
    {
        return Err(format!(
            "after full undo: undo={} redo={}, expected 0/3",
            ctx.sbc.model::<TextureModel>().history.undo_depth(),
            ctx.sbc.model::<TextureModel>().history.redo_depth()
        ));
    }

    for (label, want) in [("redo1", p1), ("redo2", p2), ("redo3", p3)] {
        ctx.sbc.model::<TextureModel>().history.redo_stroke(None);
        let got = read_first_pixel(ctx, &tile).ok_or("read during redo")?;
        if !approx_eq(got, want) {
            return Err(format!("{label}: tile {got:?}, expected {want:?}"));
        }
    }
    if ctx.sbc.model::<TextureModel>().history.undo_depth() != 3
        || ctx.sbc.model::<TextureModel>().history.redo_depth() != 0
    {
        return Err(format!(
            "after full redo: undo={} redo={}, expected 3/0",
            ctx.sbc.model::<TextureModel>().history.undo_depth(),
            ctx.sbc.model::<TextureModel>().history.redo_depth()
        ));
    }
    Ok(())
}

/// A new stroke after an undo forks history: pending redo is dropped (textures
/// freed) and a later redo is a no-op.
fn texture_redo_fork(ctx: &mut TestCtx) -> Result<(), String> {
    generate(ctx);
    ctx.sbc.model::<TextureModel>().history.clear();
    let tile = ctx
        .sbc
        .model::<TextureModel>()
        .tiles
        .texture(0, 0)
        .ok_or("no tile (0,0)")?;

    fill(ctx, &tile, [0.0, 0.0, 1.0, 1.0]);
    let _ = fill_stroke(ctx, &tile, [1.0, 0.0, 0.0, 1.0]);
    let _ = fill_stroke(ctx, &tile, [0.0, 1.0, 0.0, 1.0]);

    ctx.sbc.model::<TextureModel>().history.pop_stack(None);
    if ctx.sbc.model::<TextureModel>().history.redo_depth() != 1 {
        return Err(format!(
            "expected one redo group, got {}",
            ctx.sbc.model::<TextureModel>().history.redo_depth()
        ));
    }

    let p3 = fill_stroke(ctx, &tile, [1.0, 1.0, 0.0, 1.0]);
    if ctx.sbc.model::<TextureModel>().history.redo_depth() != 0 {
        return Err(format!(
            "new stroke did not clear redo: redo={}",
            ctx.sbc.model::<TextureModel>().history.redo_depth()
        ));
    }

    ctx.sbc.model::<TextureModel>().history.redo_stroke(None);
    let after = read_first_pixel(ctx, &tile).ok_or("read after no-op redo")?;
    if !approx_eq(after, p3) {
        return Err(format!(
            "redo after fork changed the tile: {after:?} vs {p3:?}"
        ));
    }
    Ok(())
}

/// `clear_undo_redo` empties both stacks and any open backup group.
fn texture_clear_undo_redo(ctx: &mut TestCtx) -> Result<(), String> {
    generate(ctx);
    ctx.sbc.model::<TextureModel>().history.clear();
    let tile = ctx
        .sbc
        .model::<TextureModel>()
        .tiles
        .texture(0, 0)
        .ok_or("no tile (0,0)")?;

    fill(ctx, &tile, [0.0, 0.0, 1.0, 1.0]);
    let _ = fill_stroke(ctx, &tile, [1.0, 0.0, 0.0, 1.0]);
    let _ = fill_stroke(ctx, &tile, [0.0, 1.0, 0.0, 1.0]);
    ctx.sbc.model::<TextureModel>().history.pop_stack(None); // also leave a redo group

    // Open an un-pushed group on top.
    let _ = back_up_region(ctx, 0.0, 0.0, 0.0, 0.0);
    fill(ctx, &tile, [1.0, 1.0, 1.0, 1.0]);
    let frozen = read_first_pixel(ctx, &tile).ok_or("read before clear")?;

    ctx.sbc.model::<TextureModel>().history.clear();
    if ctx.sbc.model::<TextureModel>().history.undo_depth() != 0
        || ctx.sbc.model::<TextureModel>().history.redo_depth() != 0
    {
        return Err(format!(
            "clear left state: undo={} redo={}",
            ctx.sbc.model::<TextureModel>().history.undo_depth(),
            ctx.sbc.model::<TextureModel>().history.redo_depth()
        ));
    }

    ctx.sbc.model::<TextureModel>().history.pop_stack(None);
    let after = read_first_pixel(ctx, &tile).ok_or("read after clear+undo")?;
    if !approx_eq(after, frozen) {
        return Err(format!(
            "undo after clear changed the tile: {after:?} vs {frozen:?}"
        ));
    }
    Ok(())
}

/// Command-history clear publishes an event that drops texture backup groups by
/// command id; `ClearUndoRedoCommand` itself does not know about textures.
fn texture_history_clear_event(ctx: &mut TestCtx) -> Result<(), String> {
    generate(ctx);
    ctx.sbc.model::<TextureModel>().history.clear();
    let tile = ctx
        .sbc
        .model::<TextureModel>()
        .tiles
        .texture(0, 0)
        .ok_or("no tile (0,0)")?;
    let brush = make_filled_texture(ctx, [1.0, 1.0, 1.0, 1.0]).ok_or("brush")?;
    let pattern = make_filled_texture(ctx, [1.0, 1.0, 1.0, 1.0]).ok_or("pattern")?;

    fill(ctx, &tile, [0.0, 0.0, 1.0, 1.0]);
    route(
        ctx,
        serde_json::json!({
            "className": "TerrainChangeTextureCommand",
            "opts": {
                "x": 0.0, "z": 0.0, "size": 2048.0,
                "paintMode": "paint", "mode": "Normal",
                "diffuseColor": [1.0, 0.0, 0.0, 1.0],
                "strength": 1.0, "falloffFactor": 0.0, "featureFactor": 0.0,
                "patternTexture": pattern,
                "brushTexture": { "diffuse": brush },
                "diffuseEnabled": true,
            }
        }),
    );
    route(
        ctx,
        serde_json::json!({
            "className": "TerrainChangeTextureMergedCommand",
            "__cmd_id": 4242
        }),
    );

    if ctx.sbc.model::<TextureModel>().history.undo_depth() != 1 {
        return Err(format!(
            "expected one texture undo group before clear, got {}",
            ctx.sbc.model::<TextureModel>().history.undo_depth()
        ));
    }

    route(
        ctx,
        serde_json::json!({ "className": "ClearUndoRedoCommand" }),
    );

    if ctx.sbc.model::<TextureModel>().history.undo_depth() != 0
        || ctx.sbc.model::<TextureModel>().history.redo_depth() != 0
    {
        return Err(format!(
            "history clear event left texture state: undo={} redo={}",
            ctx.sbc.model::<TextureModel>().history.undo_depth(),
            ctx.sbc.model::<TextureModel>().history.redo_depth()
        ));
    }
    Ok(())
}

/// The whole stroke through the command bridge: multi-command mode, paints,
/// close stroke, undo, and redo.
fn texture_command_stroke_undo_redo(ctx: &mut TestCtx) -> Result<(), String> {
    generate(ctx);
    let tile = ctx
        .sbc
        .model::<TextureModel>()
        .tiles
        .texture(0, 0)
        .ok_or("no tile (0,0)")?;
    let brush = make_filled_texture(ctx, [1.0, 1.0, 1.0, 1.0]).ok_or("brush")?;
    let pattern = make_filled_texture(ctx, [1.0, 1.0, 1.0, 1.0]).ok_or("pattern")?;

    // Hermetic baseline: earlier tests share this engine boot.
    ctx.sbc.model::<TextureModel>().history.clear();
    let undo0 = ctx.sbc.model::<TextureModel>().history.undo_depth();

    fill(ctx, &tile, [0.0, 0.0, 1.0, 1.0]);
    let baseline = read_pixel(ctx, &tile, 512, 512).ok_or("read baseline")?;

    let set_mode = |ctx: &mut TestCtx, on: bool| {
        route(
            ctx,
            serde_json::json!({ "className": "SetMultipleCommandModeCommand", "state": on }),
        );
    };
    let paint = |ctx: &mut TestCtx| {
        route(
            ctx,
            serde_json::json!({
                "className": "TerrainChangeTextureCommand",
                "opts": {
                    "x": 0.0, "z": 0.0, "size": 2048.0,
                    "paintMode": "paint", "mode": "Normal",
                    "diffuseColor": [1.0, 0.0, 0.0, 1.0],
                    "strength": 1.0, "falloffFactor": 0.0, "featureFactor": 0.0,
                    "patternTexture": pattern,
                    "brushTexture": { "diffuse": brush },
                    "diffuseEnabled": true,
                }
            }),
        );
    };

    set_mode(ctx, true);
    paint(ctx);
    paint(ctx);
    set_mode(ctx, false);
    route(
        ctx,
        serde_json::json!({ "className": "TerrainChangeTextureMergedCommand" }),
    );

    if ctx.sbc.model::<TextureModel>().history.undo_depth() != undo0 + 1
        || ctx.sbc.model::<TextureModel>().history.redo_depth() != 0
    {
        return Err(format!(
            "stroke did not close into one undo group: undo={} (want {}) redo={}",
            ctx.sbc.model::<TextureModel>().history.undo_depth(),
            undo0 + 1,
            ctx.sbc.model::<TextureModel>().history.redo_depth()
        ));
    }
    let after = read_pixel(ctx, &tile, 512, 512).ok_or("read after paint")?;
    if approx_eq(after, baseline) {
        return Err(format!(
            "paint produced no change: after {after:?} == baseline"
        ));
    }

    route(ctx, serde_json::json!({ "className": "UndoCommand" }));
    if ctx.sbc.model::<TextureModel>().history.undo_depth() != undo0
        || ctx.sbc.model::<TextureModel>().history.redo_depth() != 1
    {
        return Err(format!(
            "after undo: undo={} (want {undo0}) redo={} (want 1)",
            ctx.sbc.model::<TextureModel>().history.undo_depth(),
            ctx.sbc.model::<TextureModel>().history.redo_depth()
        ));
    }
    let undone = read_pixel(ctx, &tile, 512, 512).ok_or("read after undo")?;
    if !approx_eq(undone, baseline) {
        return Err(format!(
            "undo did not restore baseline: {undone:?} vs {baseline:?}"
        ));
    }

    route(ctx, serde_json::json!({ "className": "RedoCommand" }));
    if ctx.sbc.model::<TextureModel>().history.undo_depth() != undo0 + 1
        || ctx.sbc.model::<TextureModel>().history.redo_depth() != 0
    {
        return Err(format!(
            "after redo: undo={} (want {}) redo={} (want 0)",
            ctx.sbc.model::<TextureModel>().history.undo_depth(),
            undo0 + 1,
            ctx.sbc.model::<TextureModel>().history.redo_depth()
        ));
    }
    let redone = read_pixel(ctx, &tile, 512, 512).ok_or("read after redo")?;
    if !approx_eq(redone, after) {
        return Err(format!(
            "redo did not reapply paint: {redone:?} vs {after:?}"
        ));
    }
    Ok(())
}

fn texture_command_multi_stroke_redo(ctx: &mut TestCtx) -> Result<(), String> {
    generate(ctx);
    route(
        ctx,
        serde_json::json!({ "className": "ClearUndoRedoCommand" }),
    );
    ctx.sbc.model::<TextureModel>().history.clear();

    let tile = ctx
        .sbc
        .model::<TextureModel>()
        .tiles
        .texture(0, 0)
        .ok_or("no tile (0,0)")?;
    let brush = make_filled_texture(ctx, [1.0, 1.0, 1.0, 1.0]).ok_or("brush")?;
    let pattern = make_filled_texture(ctx, [1.0, 1.0, 1.0, 1.0]).ok_or("pattern")?;

    fill(ctx, &tile, [0.0, 0.0, 1.0, 1.0]);
    let baseline = read_pixel(ctx, &tile, 512, 512).ok_or("read baseline")?;

    let stroke = |ctx: &mut TestCtx, id: u64, color: [f32; 4]| -> Result<(f32, f32, f32), String> {
        route(
            ctx,
            serde_json::json!({
                "className": "TerrainChangeTextureCommand",
                "opts": {
                    "x": 0.0, "z": 0.0, "size": 2048.0,
                    "paintMode": "paint", "mode": "Normal",
                    "diffuseColor": color,
                    "strength": 1.0, "falloffFactor": 0.0, "featureFactor": 0.0,
                    "patternTexture": pattern,
                    "brushTexture": { "diffuse": brush },
                    "diffuseEnabled": true,
                }
            }),
        );
        route(
            ctx,
            serde_json::json!({
                "className": "TerrainChangeTextureMergedCommand",
                "__cmd_id": id,
            }),
        );
        read_pixel(ctx, &tile, 512, 512).ok_or_else(|| format!("read after stroke {id}"))
    };

    let first = stroke(ctx, 6101, [1.0, 0.0, 0.0, 1.0])?;
    let second = stroke(ctx, 6102, [0.0, 1.0, 0.0, 1.0])?;
    let third = stroke(ctx, 6103, [1.0, 1.0, 1.0, 1.0])?;

    if ctx.sbc.model::<TextureModel>().history.undo_depth() != 3 {
        return Err(format!(
            "expected 3 texture undo groups, got {}",
            ctx.sbc.model::<TextureModel>().history.undo_depth()
        ));
    }

    for (label, want) in [
        ("undo third", second),
        ("undo second", first),
        ("undo first", baseline),
    ] {
        route(ctx, serde_json::json!({ "className": "UndoCommand" }));
        let got = read_pixel(ctx, &tile, 512, 512).ok_or(label)?;
        if !approx_eq(got, want) {
            return Err(format!("{label}: got {got:?}, want {want:?}"));
        }
    }

    if ctx.sbc.model::<TextureModel>().history.redo_depth() != 3 {
        return Err(format!(
            "expected 3 texture redo groups after undo ladder, got {}",
            ctx.sbc.model::<TextureModel>().history.redo_depth()
        ));
    }

    for (label, want) in [
        ("redo first", first),
        ("redo second", second),
        ("redo third", third),
    ] {
        route(ctx, serde_json::json!({ "className": "RedoCommand" }));
        let got = read_pixel(ctx, &tile, 512, 512).ok_or(label)?;
        if !approx_eq(got, want) {
            return Err(format!("{label}: got {got:?}, want {want:?}"));
        }
    }

    if ctx.sbc.model::<TextureModel>().history.undo_depth() != 3
        || ctx.sbc.model::<TextureModel>().history.redo_depth() != 0
    {
        return Err(format!(
            "after redo ladder: undo={} redo={}, expected 3/0",
            ctx.sbc.model::<TextureModel>().history.undo_depth(),
            ctx.sbc.model::<TextureModel>().history.redo_depth()
        ));
    }
    Ok(())
}

/// Tile undo via the export pipeline: baseline, paint, restored PNGs for Python
/// to byte-compare (paint changed something; undo restored the exact bytes).
fn tile_undo_pixel_roundtrip(ctx: &mut TestCtx) -> Result<(), String> {
    generate(ctx);
    ctx.sbc.model::<TextureModel>().history.clear();
    let dir = artifact_dir();
    let tile_name = ctx
        .sbc
        .model::<TextureModel>()
        .tiles
        .texture(0, 0)
        .ok_or("no tile (0,0)")?;
    let pattern = make_filled_texture(ctx, [1.0, 1.0, 1.0, 1.0]).ok_or("pattern")?;

    fill(ctx, &tile_name, [0.0, 0.0, 1.0, 1.0]);
    let baseline_buf = read_texture_rgba(ctx, &tile_name, 1024, 1024).ok_or("read baseline")?;
    save_texture_png(
        ctx,
        &tile_name,
        1024,
        1024,
        &dir.join("tile_undo_baseline.png"),
    )?;

    route(
        ctx,
        serde_json::json!({
            "className": "TerrainChangeTextureCommand",
            "opts": {
                "x": 0.0, "z": 0.0, "size": 2048.0,
                "paintMode": "void", "patternRotation": 0.0,
                "patternTexture": pattern, "voidFactor": 1.0,
            }
        }),
    );
    ctx.sbc.model::<TextureModel>().history.push_stack(None);
    save_texture_png(
        ctx,
        &tile_name,
        1024,
        1024,
        &dir.join("tile_undo_after.png"),
    )?;
    let after_buf = read_texture_rgba(ctx, &tile_name, 1024, 1024).ok_or("read after")?;
    if !buffers_differ(&baseline_buf, &after_buf) {
        return Err("paint did not visibly change the tile".to_string());
    }

    ctx.sbc.model::<TextureModel>().history.pop_stack(None);
    save_texture_png(
        ctx,
        &tile_name,
        1024,
        1024,
        &dir.join("tile_undo_restored.png"),
    )?;
    let restored_buf = read_texture_rgba(ctx, &tile_name, 1024, 1024).ok_or("read restored")?;
    if buffers_differ(&baseline_buf, &restored_buf) {
        return Err("undo did not restore baseline".to_string());
    }
    Ok(())
}

crate::integration_test!("texture_model_undo", texture_model_undo);
crate::integration_test!("texture_undo_redo_ladder", texture_undo_redo_ladder);
crate::integration_test!("texture_redo_fork", texture_redo_fork);
crate::integration_test!("texture_clear_undo_redo", texture_clear_undo_redo);
crate::integration_test!("texture_history_clear_event", texture_history_clear_event);
crate::integration_test!(
    "texture_command_stroke_undo_redo",
    texture_command_stroke_undo_redo
);
crate::integration_test!(
    "texture_command_multi_stroke_redo",
    texture_command_multi_stroke_redo
);
crate::integration_test!("tile_undo_pixel_roundtrip", tile_undo_pixel_roundtrip);
