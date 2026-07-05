use std::path::Path;

use spring_native::prelude::NativeInterfaceRef;

use super::layout::texture_files;
use crate::sbc::textures::model::graphics::save_texture_png;
use crate::sbc::textures::model::TextureModel;

/// Writes the diffuse tiles and shading textures into `path` as PNGs.
pub(crate) fn save(
    interface: &NativeInterfaceRef,
    tm: &mut TextureModel,
    path: &Path,
    is_new_project: bool,
) -> Result<(), String> {
    std::fs::create_dir_all(path).map_err(|err| format!("create {}: {err}", path.display()))?;
    if is_new_project {
        for file in texture_files(path)? {
            std::fs::remove_file(&file)
                .map_err(|err| format!("remove {}: {err}", file.display()))?;
        }
    }

    for shading in tm.shading.textures() {
        if shading.dirty || is_new_project {
            let out = path.join(format!("shading-{}.png", shading.name));
            save_texture_png(
                interface,
                &shading.texture,
                shading.width,
                shading.height,
                &out,
            )?;
            if let Some(surface) = tm.shading.mark_clean(&shading.name) {
                tm.history.mark_backups_dirty_for(&surface);
            }
        }
    }

    let tile_size = tm
        .tiles
        .grid()
        .map(|(tile_size, _, _)| tile_size)
        .unwrap_or_else(|| tm.tiles.texture_size());
    for (i, j, surface) in tm.tiles.iter() {
        let (texture, dirty) = {
            let obj = surface.borrow();
            (obj.texture.clone(), obj.dirty)
        };
        if dirty || is_new_project {
            let out = path.join(format!("texture-{i}-{j}.png"));
            save_texture_png(interface, &texture, tile_size, tile_size, &out)?;
            surface.borrow_mut().dirty = false;
            tm.history.mark_backups_dirty_for(surface);
        }
    }
    Ok(())
}
