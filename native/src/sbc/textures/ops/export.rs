use std::path::Path;

use spring_native::prelude::{constants, NativeInterfaceRef};

use crate::sbc::textures::model::graphics::{self, save_texture_png};
use crate::sbc::textures::model::TextureModel;

/// Stitches every diffuse tile into one full-map image and writes it to `path`.
pub(crate) fn export_diffuse(
    interface: &NativeInterfaceRef,
    tm: &mut TextureModel,
    path: &Path,
) -> Result<(), String> {
    let Some((tile_size, tiles_x, tiles_z)) = tm.tiles.grid() else {
        return Err("export diffuse: could not initialize tile store".to_string());
    };
    let width = (tiles_x + 1) * tile_size;
    let height = (tiles_z + 1) * tile_size;
    let Some(total) = graphics::create_fbo_texture(interface, width, height) else {
        return Err(format!(
            "export diffuse: create {width}x{height} texture failed"
        ));
    };
    let gfx = interface.gfx();
    gfx.render_to_texture(&total, || {
        let _ = gfx.clear(constants::GL_COLOR_BUFFER_BIT, [0.0, 0.0, 0.0, 0.0], 4);
        for (i, j, surface) in tm.tiles.iter() {
            let texture = surface.borrow().texture.clone();
            let x1 = -1.0 + 2.0 * (i * tile_size) as f32 / width as f32;
            let x2 = -1.0 + 2.0 * ((i + 1) * tile_size) as f32 / width as f32;
            let y1 = -1.0 + 2.0 * ((tiles_z - j) * tile_size) as f32 / height as f32;
            let y2 = -1.0 + 2.0 * ((tiles_z - j + 1) * tile_size) as f32 / height as f32;
            let _ = gfx.bind_texture(&texture, 0, true);
            let _ = gfx.tex_rect(x1, y1, x2, y2, 0.0, 0.0, 1.0, 1.0);
            let _ = gfx.bind_texture(&texture, 0, false);
        }
    })
    .map_err(|err| format!("render diffuse export: {err:?}"))?;
    let result = save_texture_png(interface, &total, width, height, path);
    let _ = interface.gfx().delete_texture(&total);
    result
}

/// Writes each shading texture to `{name}.png` under `path`.
pub(crate) fn export_shading_textures(
    interface: &NativeInterfaceRef,
    tm: &mut TextureModel,
    path: &Path,
) -> Result<(), String> {
    std::fs::create_dir_all(path).map_err(|err| format!("create {}: {err}", path.display()))?;
    for shading in tm.shading.textures() {
        let out = path.join(format!("{}.png", shading.name));
        save_texture_png(
            interface,
            &shading.texture,
            shading.width,
            shading.height,
            &out,
        )?;
    }
    Ok(())
}
