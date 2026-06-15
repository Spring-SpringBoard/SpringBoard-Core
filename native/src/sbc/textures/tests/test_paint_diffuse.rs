//! Diffuse paint behaviour.

use crate::sbc::tests::tests_api::TestCtx;
use crate::sbc::textures::model::graphics;
use crate::sbc::textures::TextureModel;

use super::test_support::{
    approx_eq, artifact_dir, back_up_region, buffers_differ, fill, generate, make_filled_texture,
    read_pixel, read_texture_rgba, save_texture_png,
};

/// A full-coverage opaque stroke paints the brush colour and marks the tile dirty.
/// Normal blend mixes the brush over the tile, so the centre moves toward red (red
/// rises, blue falls, green stays absent). Exports before/after PNGs.
fn terrain_paint_diffuse(ctx: &mut TestCtx) -> Result<(), String> {
    generate(ctx);
    let tile = ctx
        .sbc
        .model::<TextureModel>()
        .tiles
        .texture(0, 0)
        .ok_or("no tile (0,0)")?;
    let red = make_filled_texture(ctx, [1.0, 0.0, 0.0, 1.0]).ok_or("brush")?;
    let opaque = make_filled_texture(ctx, [1.0, 1.0, 1.0, 1.0]).ok_or("pattern")?;
    let dir = artifact_dir();

    fill(ctx, &tile, [0.0, 0.0, 1.0, 1.0]);
    save_texture_png(ctx, &tile, 1024, 1024, &dir.join("paint_paint_before.png"))
        .map_err(|e| format!("save before: {e}"))?;
    ctx.route_command(serde_json::json!({
        "className": "TerrainChangeTextureCommand",
        "opts": {
            "x": 0.0, "z": 0.0, "size": 2048.0,
            "paintMode": "paint", "mode": "Normal", "patternRotation": 0.0,
            "diffuseColor": [1.0, 1.0, 1.0, 1.0],
            "strength": 1.0, "falloffFactor": 0.0, "featureFactor": 0.0,
            "patternTexture": opaque,
            "brushTexture": { "diffuse": red },
            "diffuseEnabled": true,
        }
    }));
    save_texture_png(ctx, &tile, 1024, 1024, &dir.join("paint_paint_after.png"))
        .map_err(|e| format!("save after: {e}"))?;

    if !ctx.sbc.model::<TextureModel>().tiles.dirty(0, 0) {
        return Err("tile not marked dirty after paint".into());
    }
    let center = read_pixel(ctx, &tile, 512, 512).ok_or("read centre")?;
    if center.0 < 0.3 || center.2 > 0.7 || center.1 > 0.2 {
        return Err(format!("centre not painted toward red: {center:?}"));
    }
    Ok(())
}

/// A localized stroke changes the tile but stays inside its radius: the far
/// corners are untouched.
fn terrain_paint_diffuse_stays_in_radius(ctx: &mut TestCtx) -> Result<(), String> {
    generate(ctx);
    let tile = ctx
        .sbc
        .model::<TextureModel>()
        .tiles
        .texture(0, 0)
        .ok_or("no tile (0,0)")?;
    let red = make_filled_texture(ctx, [1.0, 0.0, 0.0, 1.0]).ok_or("brush")?;
    let opaque = make_filled_texture(ctx, [1.0, 1.0, 1.0, 1.0]).ok_or("pattern")?;

    fill(ctx, &tile, [0.0, 0.0, 1.0, 1.0]);
    let before_buf = read_texture_rgba(ctx, &tile, 1024, 1024).ok_or("read before")?;
    let edges = [(10, 10), (10, 512), (512, 10), (49, 700), (700, 49)];
    let edge_before: Vec<_> = edges
        .iter()
        .map(|&(x, y)| read_pixel(ctx, &tile, x, y).ok_or("read edge before"))
        .collect::<Result<_, _>>()?;
    ctx.route_command(serde_json::json!({
        "className": "TerrainChangeTextureCommand",
        "opts": {
            "x": 462.0, "z": 462.0, "size": 100.0,
            "paintMode": "paint", "mode": "Normal", "patternRotation": 0.0,
            "diffuseColor": [1.0, 1.0, 1.0, 1.0],
            "strength": 1.0, "falloffFactor": 0.0, "featureFactor": 0.0,
            "patternTexture": opaque,
            "brushTexture": { "diffuse": red },
            "diffuseEnabled": true,
        }
    }));
    let after_buf = read_texture_rgba(ctx, &tile, 1024, 1024).ok_or("read after")?;
    if !buffers_differ(&before_buf, &after_buf) {
        return Err("localized paint did not change the tile".into());
    }
    for (&(x, y), before) in edges.iter().zip(&edge_before) {
        let after = read_pixel(ctx, &tile, x, y).ok_or("read edge after")?;
        if !approx_eq(after, *before) {
            return Err(format!(
                "paint bled to edge ({x},{y}): {after:?} vs {before:?}"
            ));
        }
    }
    Ok(())
}

/// A transparent pattern (region gate) or transparent brush (colour gate) paints
/// nothing.
fn terrain_paint_diffuse_transparent_noop(ctx: &mut TestCtx) -> Result<(), String> {
    generate(ctx);
    let tile = ctx
        .sbc
        .model::<TextureModel>()
        .tiles
        .texture(0, 0)
        .ok_or("no tile (0,0)")?;
    let red = make_filled_texture(ctx, [1.0, 0.0, 0.0, 1.0]).ok_or("brush")?;
    let opaque = make_filled_texture(ctx, [1.0, 1.0, 1.0, 1.0]).ok_or("pattern")?;
    let clear_pattern = make_filled_texture(ctx, [1.0, 1.0, 1.0, 0.0]).ok_or("clear pattern")?;
    let clear_brush = make_filled_texture(ctx, [1.0, 0.0, 0.0, 0.0]).ok_or("clear brush")?;

    for (label, pattern, brush) in [
        ("pattern", &clear_pattern, &red),
        ("brush", &opaque, &clear_brush),
    ] {
        fill(ctx, &tile, [0.0, 0.0, 1.0, 1.0]);
        let before = read_texture_rgba(ctx, &tile, 1024, 1024).ok_or("read before")?;
        ctx.route_command(serde_json::json!({
            "className": "TerrainChangeTextureCommand",
            "opts": {
                "x": 462.0, "z": 462.0, "size": 100.0,
                "paintMode": "paint", "mode": "Normal", "patternRotation": 0.0,
                "diffuseColor": [1.0, 1.0, 1.0, 1.0],
                "strength": 1.0, "falloffFactor": 0.0, "featureFactor": 1.0,
                "patternTexture": pattern,
                "brushTexture": { "diffuse": brush },
                "diffuseEnabled": true,
            }
        }));
        let after = read_texture_rgba(ctx, &tile, 1024, 1024).ok_or("read after")?;
        if buffers_differ(&before, &after) {
            return Err(format!("transparent {label} changed the tile"));
        }
    }
    Ok(())
}

/// Paints with real shipped brush/pattern assets, confirming they sample to a
/// non-black colour that changes the tile (catches asset/sampler regressions that
/// synthetic single-colour textures would hide).
fn terrain_paint_live_assets_color(ctx: &mut TestCtx) -> Result<(), String> {
    generate(ctx);
    let interface = *ctx.sbc.interface();
    let pattern_name = "springboard/assets/core/brush_patterns/terrain/circle1.png";
    let brush_name = "springboard/assets/core/brush_textures/snow_diffuse.png";
    let brush_copy =
        graphics::copy_texture(&interface, &graphics::Texture::from(brush_name.to_string()))
            .ok_or("copy live brush texture into native FBO failed")?;
    let brush_center = read_pixel(ctx, &brush_copy, 512, 512).ok_or("read brush copy center")?;
    let _ = interface.gfx().delete_texture(&brush_copy);
    ctx.route_command(serde_json::json!({
        "className": "CacheTextureCommand",
        "texture": { "diffuse": brush_name }
    }));

    let tile_name = ctx
        .sbc
        .model::<TextureModel>()
        .tiles
        .texture(0, 0)
        .ok_or("no tile (0,0)")?;

    fill(ctx, &tile_name, [0.0, 0.0, 1.0, 1.0]);
    let baseline = read_pixel(ctx, &tile_name, 512, 512).ok_or("read baseline")?;

    ctx.route_command(serde_json::json!({
        "className": "TerrainChangeTextureCommand",
        "opts": {
            "x": 462.0, "z": 462.0, "size": 100.0,
            "paintMode": "paint", "mode": "Normal", "patternRotation": 0.0,
            "diffuseColor": [1.0, 1.0, 1.0, 1.0],
            "strength": 1.0, "falloffFactor": 0.0, "featureFactor": 1.0,
            "texScale": 2.0,
            "patternTexture": pattern_name,
            "brushTexture": { "diffuse": brush_name },
            "diffuseEnabled": true,
        }
    }));

    let after = read_pixel(ctx, &tile_name, 512, 512).ok_or("read after paint")?;
    if after.0 < 0.2 && after.1 < 0.2 && after.2 < 0.2 {
        return Err(format!(
            "live asset paint produced near-black center pixel: {after:?}; brush copy center was {brush_center:?}"
        ));
    }
    if approx_eq(after, baseline) {
        return Err(format!(
            "live asset paint did not change center pixel: {after:?} vs {baseline:?}"
        ));
    }
    Ok(())
}

/// Backing up a region for undo must read the tiles without mutating them.
fn terrain_paint_get_map_textures_preserves_tile(ctx: &mut TestCtx) -> Result<(), String> {
    generate(ctx);
    let tile_name = ctx
        .sbc
        .model::<TextureModel>()
        .tiles
        .texture(0, 0)
        .ok_or("no tile (0,0)")?;
    fill(ctx, &tile_name, [0.0, 0.0, 1.0, 1.0]);
    let baseline = read_pixel(ctx, &tile_name, 512, 512).ok_or("read baseline")?;
    let tiles = back_up_region(
        ctx,
        462.0 / 1024.0,
        462.0 / 1024.0,
        562.0 / 1024.0,
        562.0 / 1024.0,
    );
    if tiles.len() != 1 {
        return Err(format!("expected one region tile, got {}", tiles.len()));
    }
    let after = read_pixel(ctx, &tile_name, 512, 512).ok_or("read after get_map_textures")?;
    if !approx_eq(after, baseline) {
        return Err(format!(
            "get_map_textures changed tile pixel: {after:?} vs {baseline:?}"
        ));
    }
    Ok(())
}

crate::integration_test!("terrain_paint_diffuse", terrain_paint_diffuse);
crate::integration_test!(
    "terrain_paint_diffuse_stays_in_radius",
    terrain_paint_diffuse_stays_in_radius
);
crate::integration_test!(
    "terrain_paint_diffuse_transparent_noop",
    terrain_paint_diffuse_transparent_noop
);
crate::integration_test!(
    "terrain_paint_live_assets_color",
    terrain_paint_live_assets_color
);
crate::integration_test!(
    "terrain_paint_get_map_textures_preserves_tile",
    terrain_paint_get_map_textures_preserves_tile
);
