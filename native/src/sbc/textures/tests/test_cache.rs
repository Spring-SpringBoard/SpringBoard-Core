//! `CacheTextureCommand`: a cached name resolves to a different (FBO copy) name,
//! so the draw passes sample the cached copy instead of whatever's bound at unit 0.

use super::test_support::make_filled_texture;
use crate::sbc::tests::tests_api::TestCtx;
use crate::sbc::textures::TextureModel;

fn cache_texture_roundtrip(ctx: &mut TestCtx) -> Result<(), String> {
    let synthetic = make_filled_texture(ctx, [1.0, 0.5, 0.25, 1.0]).ok_or("synthetic")?;
    if ctx.sbc.model::<TextureModel>().cache.get(&synthetic) != synthetic {
        return Err("get_texture returned a cached entry before any cache call".to_string());
    }

    ctx.route_command(
        serde_json::json!({ "className": "CacheTextureCommand", "texture": [synthetic.clone()] }),
    );

    if ctx.sbc.model::<TextureModel>().cache.get(&synthetic) == synthetic {
        return Err(
            "get_texture still returns the source name; CacheTextureCommand was a no-op"
                .to_string(),
        );
    }
    Ok(())
}

crate::integration_test!("cache_texture_roundtrip", cache_texture_roundtrip);

fn cache_texture_material_table(ctx: &mut TestCtx) -> Result<(), String> {
    let diffuse = make_filled_texture(ctx, [1.0, 0.5, 0.25, 1.0]).ok_or("diffuse")?;
    let normal = make_filled_texture(ctx, [0.25, 0.5, 1.0, 1.0]).ok_or("normal")?;

    ctx.route_command(serde_json::json!({
        "className": "CacheTextureCommand",
        "texture": {
            "diffuse": diffuse.clone(),
            "normal": normal.clone()
        }
    }));

    if ctx.sbc.model::<TextureModel>().cache.get(&diffuse) == diffuse {
        return Err("diffuse material entry was not cached".to_string());
    }
    if ctx.sbc.model::<TextureModel>().cache.get(&normal) == normal {
        return Err("normal material entry was not cached".to_string());
    }
    Ok(())
}

crate::integration_test!("cache_texture_material_table", cache_texture_material_table);
