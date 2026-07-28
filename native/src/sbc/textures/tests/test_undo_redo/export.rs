//! The artifact-producing undo regression stays isolated from stack semantics.

use crate::sbc::tests::tests_api::TestCtx;
use crate::sbc::textures::TextureModel;

use super::{
    artifact_dir, buffers_differ, fill, generate, make_filled_texture, read_texture_rgba, route,
    save_texture_png,
};

pub(super) fn tile_undo_pixel_roundtrip(ctx: &mut TestCtx) -> Result<(), String> {
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
        serde_json::json!({ "className": "TerrainChangeTextureCommand", "opts": { "x": 0.0, "z": 0.0, "size": 2048.0, "paintMode": "void", "patternRotation": 0.0, "patternTexture": pattern, "voidFactor": 1.0 } }),
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
