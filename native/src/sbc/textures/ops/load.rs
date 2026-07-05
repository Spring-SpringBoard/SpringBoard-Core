use std::path::Path;

use spring_native::prelude::NativeInterfaceRef;

use super::layout::{parse_tile_file, texture_files};
use crate::sbc::textures::model::graphics::load_image_texture;
use crate::sbc::textures::model::texture_model::ShadingStore;
use crate::sbc::textures::model::TextureModel;

/// Reads the diffuse tiles and shading textures saved under `path` back into
/// the model.
pub(crate) fn load(
    interface: &NativeInterfaceRef,
    tm: &mut TextureModel,
    path: &Path,
) -> Result<(), String> {
    if !path.is_dir() {
        return Ok(());
    }
    tm.tiles.clear();
    if tm.tiles.grid().is_none() {
        return Err("load textures: could not initialize tile store".to_string());
    }

    for file in texture_files(path)? {
        let Some(name) = file.file_name().and_then(|name| name.to_str()) else {
            continue;
        };
        if let Some((i, j)) = parse_tile_file(name) {
            let tex = load_image_texture(interface, &file)?;
            tm.tiles.set_tile(i, j, &tex, false);
            let _ = interface.gfx().delete_texture(&tex);
        }
    }

    for name in ShadingStore::names() {
        let file = path.join(format!("shading-{name}.png"));
        if !file.is_file() {
            continue;
        }
        let tex = load_image_texture(interface, &file)?;
        tm.shading.set_from_source(name, &tex, false);
        let _ = interface.gfx().delete_texture(&tex);
    }
    Ok(())
}
