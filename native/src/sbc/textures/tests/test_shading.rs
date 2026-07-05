//! Shading texture paint and undo behavior.

use super::test_support::{
    artifact_dir, bind_engine_shading_texture, buffers_differ, generate, make_filled_texture,
    read_pixel_rgba, read_texture_rgba, save_texture_png,
};
use crate::sbc::tests::tests_api::TestCtx;
use crate::sbc::textures::model::graphics::Texture;
use crate::sbc::textures::TextureModel;

fn route(ctx: &mut TestCtx, data: serde_json::Value) {
    ctx.route_command(data);
}

fn mirror_shading_texture(
    ctx: &mut TestCtx,
    name: &str,
    bind_type: &str,
    slot: i32,
) -> Result<(Texture, i32, i32), String> {
    let source = bind_engine_shading_texture(ctx, bind_type, slot, [0.0, 0.0, 0.0, 1.0])
        .ok_or_else(|| format!("failed to bind engine shading texture {bind_type}"))?;
    let shading = &mut ctx.sbc.model::<TextureModel>().shading;
    if !shading.set_from_source(name, &source, false) && !shading.ensure(name, Some(&source)) {
        return Err(format!("failed to mirror shading texture {name}"));
    }
    ctx.sbc
        .model::<TextureModel>()
        .shading
        .texture(name)
        .map(|t| (t.texture, t.width, t.height))
        .ok_or_else(|| format!("missing mirrored shading texture {name}"))
}

fn shading_specular_visual(ctx: &mut TestCtx) -> Result<(), String> {
    generate(ctx);
    let (target, w, h) = mirror_shading_texture(ctx, "specular", "$ssmf_specular", 0)?;
    let dir = artifact_dir();

    let brush = make_filled_texture(ctx, [1.0, 1.0, 1.0, 1.0]).ok_or("brush")?;
    let pattern = make_filled_texture(ctx, [1.0, 1.0, 1.0, 1.0]).ok_or("pattern")?;

    save_texture_png(ctx, &target, w, h, &dir.join("shading_specular_before.png"))?;
    let before_buf = read_texture_rgba(ctx, &target, w, h).ok_or("read specular before")?;

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
                "brushTexture": { "specular": brush },
                "specularEnabled": true, "diffuseEnabled": false,
            }
        }),
    );

    save_texture_png(ctx, &target, w, h, &dir.join("shading_specular_after.png"))?;
    let after_buf = read_texture_rgba(ctx, &target, w, h).ok_or("read specular after")?;
    if !buffers_differ(&before_buf, &after_buf) {
        return Err("specular paint did not visibly change the target".to_string());
    }
    Ok(())
}

fn shading_undo_pixel_roundtrip(ctx: &mut TestCtx) -> Result<(), String> {
    generate(ctx);
    let (target, w, h) = mirror_shading_texture(ctx, "splat_distr", "$ssmf_splat_distr", 0)?;
    let dir = artifact_dir();
    let pattern = make_filled_texture(ctx, [1.0, 1.0, 1.0, 1.0]).ok_or("pattern")?;

    save_texture_png(ctx, &target, w, h, &dir.join("shading_undo_baseline.png"))?;
    let baseline_buf = read_texture_rgba(ctx, &target, w, h).ok_or("read shading baseline")?;

    route(
        ctx,
        serde_json::json!({
            "className": "TerrainChangeTextureCommand",
            "opts": {
                "x": 0.0, "z": 0.0, "size": 2048.0,
                "paintMode": "dnts", "patternRotation": 0.0,
                "patternTexture": pattern, "strength": 1.0,
                "colorIndex": 1, "exclusive": 1, "value": 1.0,
            }
        }),
    );
    ctx.sbc.model::<TextureModel>().history.push_stack(None);
    save_texture_png(ctx, &target, w, h, &dir.join("shading_undo_after.png"))?;
    let after_buf = read_texture_rgba(ctx, &target, w, h).ok_or("read shading after")?;
    if !buffers_differ(&baseline_buf, &after_buf) {
        return Err("DNTS paint did not visibly change the target".to_string());
    }

    ctx.sbc.model::<TextureModel>().history.pop_stack(None);
    save_texture_png(ctx, &target, w, h, &dir.join("shading_undo_restored.png"))?;
    let restored_buf = read_texture_rgba(ctx, &target, w, h).ok_or("read shading restored")?;
    if buffers_differ(&baseline_buf, &restored_buf) {
        return Err("shading undo did not restore baseline".to_string());
    }
    Ok(())
}

fn shading_dnts_alpha_preserves(ctx: &mut TestCtx) -> Result<(), String> {
    generate(ctx);
    let (target, _, _) = mirror_shading_texture(ctx, "splat_distr", "$ssmf_splat_distr", 0)?;
    let pattern = make_filled_texture(ctx, [1.0, 1.0, 1.0, 0.0]).ok_or("pattern")?;
    let baseline = read_pixel_rgba(ctx, &target, 128, 128).ok_or("read baseline")?;

    route(
        ctx,
        serde_json::json!({
            "className": "TerrainChangeTextureCommand",
            "opts": {
                "x": 0.0, "z": 0.0, "size": 2048.0,
                "paintMode": "dnts", "patternRotation": 0.0,
                "patternTexture": pattern, "strength": 1.0,
                "colorIndex": 1, "exclusive": 1, "value": 1.0,
            }
        }),
    );

    let after = read_pixel_rgba(ctx, &target, 128, 128).ok_or("read after dnts")?;
    if (after.0 - baseline.0).abs() > 0.01
        || (after.1 - baseline.1).abs() > 0.01
        || (after.2 - baseline.2).abs() > 0.01
        || (after.3 - baseline.3).abs() > 0.01
    {
        return Err(format!(
            "transparent dnts pattern changed pixel: {after:?} vs {baseline:?}"
        ));
    }
    Ok(())
}

fn shading_mirror_paint_undo(ctx: &mut TestCtx) -> Result<(), String> {
    generate(ctx);
    ctx.sbc.model::<TextureModel>().history.clear();
    mirror_shading_texture(ctx, "specular", "$ssmf_specular", 0)?;

    let brush = make_filled_texture(ctx, [1.0, 1.0, 1.0, 1.0]).ok_or("brush")?;
    let pattern = make_filled_texture(ctx, [1.0, 1.0, 1.0, 1.0]).ok_or("pattern")?;
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
                "brushTexture": { "specular": brush },
                "specularEnabled": true, "diffuseEnabled": false,
            }
        }),
    );

    if !ctx.sbc.model::<TextureModel>().shading.dirty("specular") {
        return Err("mirrored specular texture was not painted".to_string());
    }

    ctx.sbc.model::<TextureModel>().history.push_stack(None);
    ctx.sbc.model::<TextureModel>().history.pop_stack(None);
    if ctx
        .sbc
        .model::<TextureModel>()
        .shading
        .texture("specular")
        .is_none()
    {
        return Err("specular tex lost after paint+undo".to_string());
    }
    Ok(())
}

crate::integration_test!("shading_specular_visual", shading_specular_visual);
crate::integration_test!("shading_undo_pixel_roundtrip", shading_undo_pixel_roundtrip);
crate::integration_test!("shading_dnts_alpha_preserves", shading_dnts_alpha_preserves);
crate::integration_test!("shading_mirror_paint_undo", shading_mirror_paint_undo);
