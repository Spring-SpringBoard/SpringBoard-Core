//! Blur/filter paint.

use crate::sbc::tests::tests_api::TestCtx;
use crate::sbc::textures::TextureModel;

use super::test_support::{
    artifact_dir, buffers_differ, fill, generate, make_filled_texture, read_pixel_rgba,
    read_texture_rgba, save_texture_png,
};

/// The outline kernel darkens a flat field (its weights sum to zero), exercising
/// the 3x3 matrix uniform and marking the tile dirty. Exports before/after PNGs.
fn terrain_paint_filter(ctx: &mut TestCtx) -> Result<(), String> {
    generate(ctx);
    let tile = ctx
        .sbc
        .model::<TextureModel>()
        .tiles
        .texture(0, 0)
        .ok_or("no tile (0,0)")?;
    let dir = artifact_dir();

    fill(ctx, &tile, [0.0, 0.3, 0.8, 1.0]);
    let before = read_pixel_rgba(ctx, &tile, 512, 512).ok_or("read before")?;
    save_texture_png(ctx, &tile, 1024, 1024, &dir.join("paint_blur_before.png"))
        .map_err(|e| format!("save before: {e}"))?;
    let opaque = make_filled_texture(ctx, [1.0, 1.0, 1.0, 1.0]).ok_or("opaque pattern")?;
    ctx.route_command(serde_json::json!({
        "className": "TerrainChangeTextureCommand",
        "opts": {
            "x": 0.0, "z": 0.0, "size": 2048.0,
            "paintMode": "blur", "kernelMode": "outline", "patternRotation": 0.0,
            "patternTexture": opaque, "strength": 1.0,
        }
    }));
    save_texture_png(ctx, &tile, 1024, 1024, &dir.join("paint_blur_after.png"))
        .map_err(|e| format!("save after: {e}"))?;

    if !ctx.sbc.model::<TextureModel>().tiles.dirty(0, 0) {
        return Err("tile not marked dirty after blur".into());
    }
    let after = read_pixel_rgba(ctx, &tile, 512, 512).ok_or("read after")?;
    if (after.0 - before.0).abs() < 0.05
        && (after.1 - before.1).abs() < 0.05
        && (after.2 - before.2).abs() < 0.05
    {
        return Err(format!("outline filter left pixel unchanged: {after:?} vs {before:?}"));
    }
    Ok(())
}

/// A fully transparent blur pattern changes nothing.
fn terrain_paint_filter_transparent_noop(ctx: &mut TestCtx) -> Result<(), String> {
    generate(ctx);
    let tile = ctx
        .sbc
        .model::<TextureModel>()
        .tiles
        .texture(0, 0)
        .ok_or("no tile (0,0)")?;

    fill(ctx, &tile, [0.0, 0.3, 0.8, 1.0]);
    let before = read_texture_rgba(ctx, &tile, 1024, 1024).ok_or("read before")?;
    let clear = make_filled_texture(ctx, [1.0, 1.0, 1.0, 0.0]).ok_or("clear pattern")?;
    ctx.route_command(serde_json::json!({
        "className": "TerrainChangeTextureCommand",
        "opts": {
            "x": 462.0, "z": 462.0, "size": 100.0,
            "paintMode": "blur", "kernelMode": "outline", "patternRotation": 0.0,
            "patternTexture": clear, "strength": 1.0,
        }
    }));
    let after = read_texture_rgba(ctx, &tile, 1024, 1024).ok_or("read after")?;
    if buffers_differ(&before, &after) {
        return Err("transparent filter changed the tile".into());
    }
    Ok(())
}

crate::integration_test!("terrain_paint_filter", terrain_paint_filter);
crate::integration_test!(
    "terrain_paint_filter_transparent_noop",
    terrain_paint_filter_transparent_noop
);
