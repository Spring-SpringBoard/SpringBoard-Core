use std::path::Path;

use spring_native::prelude::NativeInterfaceRef;

use crate::sbc::textures::model::graphics::{self, load_image_texture};
use crate::sbc::textures::model::TextureModel;

/// Slices one external image across every diffuse tile.
pub(crate) fn import_diffuse(
    interface: &NativeInterfaceRef,
    tm: &mut TextureModel,
    path: &Path,
) -> Result<(), String> {
    let source = load_image_texture(interface, path)?;
    let Some((tile_size, tiles_x, tiles_z)) = tm.tiles.grid() else {
        let _ = interface.gfx().delete_texture(&source);
        return Err("import diffuse: could not initialize tile store".to_string());
    };
    let count_x = tiles_x + 1;
    let count_z = tiles_z + 1;
    for i in 0..=tiles_x {
        for j in 0..=tiles_z {
            let Some(tile) = graphics::create_fbo_texture(interface, tile_size, tile_size) else {
                continue;
            };
            let gfx = interface.gfx();
            let u1 = i as f32 / count_x as f32;
            let v1 = j as f32 / count_z as f32;
            let u2 = (i + 1) as f32 / count_x as f32;
            let v2 = (j + 1) as f32 / count_z as f32;
            gfx.bind_texture(&source, 0, true)
                .map_err(|err| format!("bind source diffuse: {err:?}"))?;
            gfx.render_to_texture(&tile, || {
                let _ = gfx.tex_rect(-1.0, -1.0, 1.0, 1.0, u1, v1, u2, v2);
            })
            .map_err(|err| format!("copy diffuse tile: {err:?}"))?;
            let _ = gfx.bind_texture(&source, 0, false);
            tm.tiles.set_tile(i, j, &tile, true);
            let _ = gfx.delete_texture(&tile);
        }
    }
    let _ = interface.gfx().delete_texture(&source);
    Ok(())
}

/// Loads one external image into a named shading texture.
pub(crate) fn import_shading(
    interface: &NativeInterfaceRef,
    tm: &mut TextureModel,
    name: &str,
    path: &Path,
) -> Result<(), String> {
    let source = load_image_texture(interface, path)?;
    let ok = tm.shading.set_from_source(name, &source, true);
    let _ = interface.gfx().delete_texture(&source);
    if ok {
        Ok(())
    } else {
        Err(format!("import shading: unknown texture type {name}"))
    }
}
