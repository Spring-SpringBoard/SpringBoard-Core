//! Height paint.

use crate::sbc::tests::tests_api::TestCtx;
use crate::sbc::textures::TextureModel;

use super::test_support::{
    artifact_dir, buffers_differ, fill, generate, make_filled_texture, read_texture_rgba,
    save_texture_png,
};

/// An opaque height stroke recolours the tile from the heightmap and marks it
/// dirty. Exports before/after PNGs.
fn terrain_paint_height(ctx: &mut TestCtx) -> Result<(), String> {
    generate(ctx);
    let tile = ctx
        .sbc
        .model::<TextureModel>()
        .tiles
        .texture(0, 0)
        .ok_or("no tile (0,0)")?;
    let dir = artifact_dir();

    fill(ctx, &tile, [0.0, 0.0, 1.0, 1.0]);
    let before = read_texture_rgba(ctx, &tile, 1024, 1024).ok_or("read before")?;
    save_texture_png(ctx, &tile, 1024, 1024, &dir.join("paint_height_before.png"))
        .map_err(|e| format!("save before: {e}"))?;
    let opaque = make_filled_texture(ctx, [1.0, 1.0, 1.0, 1.0]).ok_or("opaque pattern")?;
    ctx.route_command(serde_json::json!({
        "className": "TerrainChangeTextureCommand",
        "opts": {
            "x": 0.0, "z": 0.0, "size": 2048.0,
            "paintMode": "height", "patternRotation": 0.0,
            "patternTexture": opaque, "strength": 1.0,
        }
    }));
    save_texture_png(ctx, &tile, 1024, 1024, &dir.join("paint_height_after.png"))
        .map_err(|e| format!("save after: {e}"))?;

    if !ctx.sbc.model::<TextureModel>().tiles.dirty(0, 0) {
        return Err("tile not marked dirty after height paint".into());
    }
    let after = read_texture_rgba(ctx, &tile, 1024, 1024).ok_or("read after")?;
    if !buffers_differ(&before, &after) {
        return Err("height paint did not change the tile".into());
    }
    Ok(())
}

/// A fully transparent height pattern changes nothing.
fn terrain_paint_height_transparent_noop(ctx: &mut TestCtx) -> Result<(), String> {
    generate(ctx);
    let tile = ctx
        .sbc
        .model::<TextureModel>()
        .tiles
        .texture(0, 0)
        .ok_or("no tile (0,0)")?;

    fill(ctx, &tile, [0.0, 0.0, 1.0, 1.0]);
    let before = read_texture_rgba(ctx, &tile, 1024, 1024).ok_or("read before")?;
    let clear = make_filled_texture(ctx, [1.0, 1.0, 1.0, 0.0]).ok_or("clear pattern")?;
    ctx.route_command(serde_json::json!({
        "className": "TerrainChangeTextureCommand",
        "opts": {
            "x": 462.0, "z": 462.0, "size": 100.0,
            "paintMode": "height", "patternRotation": 0.0,
            "patternTexture": clear, "strength": 1.0,
        }
    }));
    let after = read_texture_rgba(ctx, &tile, 1024, 1024).ok_or("read after")?;
    if buffers_differ(&before, &after) {
        return Err("transparent height changed the tile".into());
    }
    Ok(())
}

crate::integration_test!("terrain_paint_height", terrain_paint_height);
crate::integration_test!(
    "terrain_paint_height_transparent_noop",
    terrain_paint_height_transparent_noop
);
