//! DNTS (splat distribution) paint.

use crate::sbc::tests::tests_api::TestCtx;
use crate::sbc::textures::TextureModel;

use super::test_support::{buffers_differ, generate, make_filled_texture, read_texture_rgba};

/// `dnts` writes the `splat_distr` shading texture (not a tile): the paint both
/// marks it dirty and changes its pixels. Skips when the map ships no
/// `$ssmf_splat_distr`.
fn terrain_paint_dnts(ctx: &mut TestCtx) -> Result<(), String> {
    generate(ctx);
    let Some(splat) = ctx
        .sbc
        .model::<TextureModel>()
        .shading
        .texture("splat_distr")
    else {
        log::info!("terrain_paint_dnts: skipped, no splat_distr shading texture");
        return Ok(());
    };
    let before = read_texture_rgba(ctx, &splat.texture, splat.width, splat.height)
        .ok_or("read splat_distr before")?;

    let pattern = make_filled_texture(ctx, [1.0, 1.0, 1.0, 1.0]).ok_or("create pattern failed")?;
    ctx.route_command(serde_json::json!({
        "className": "TerrainChangeTextureCommand",
        "opts": {
            "x": 0.0, "z": 0.0, "size": 2048.0,
            "paintMode": "dnts", "patternRotation": 0.0,
            "patternTexture": pattern, "strength": 1.0,
            "colorIndex": 1, "exclusive": 1, "value": 1.0,
        }
    }));

    if !ctx.sbc.model::<TextureModel>().shading.dirty("splat_distr") {
        return Err("splat_distr not marked dirty after DNTS paint".into());
    }
    let after = read_texture_rgba(ctx, &splat.texture, splat.width, splat.height)
        .ok_or("read splat_distr after")?;
    if !buffers_differ(&before, &after) {
        return Err("DNTS paint did not change the splat_distr texture".into());
    }
    Ok(())
}

crate::integration_test!("terrain_paint_dnts", terrain_paint_dnts);
