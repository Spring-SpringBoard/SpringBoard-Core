//! Shared by [`save`](super::save) and [`load`](super::load): the on-disk file
//! layout of a saved project's textures — diffuse tiles as `texture-{i}-{j}.png`
//! and shading textures as `shading-{name}.png`.

use std::path::{Path, PathBuf};

/// The `texture-*.png` / `shading-*.png` files in a saved texture directory.
pub(crate) fn texture_files(path: &Path) -> Result<Vec<PathBuf>, String> {
    let entries =
        std::fs::read_dir(path).map_err(|err| format!("read {}: {err}", path.display()))?;
    let mut files = Vec::new();
    for entry in entries {
        let entry = entry.map_err(|err| format!("read {} entry: {err}", path.display()))?;
        let p = entry.path();
        let Some(name) = p.file_name().and_then(|name| name.to_str()) else {
            continue;
        };
        if (name.starts_with("texture-") || name.starts_with("shading-")) && name.ends_with(".png")
        {
            files.push(p);
        }
    }
    Ok(files)
}

/// `(i, j)` from a `texture-{i}-{j}.png` file name.
pub(crate) fn parse_tile_file(name: &str) -> Option<(i32, i32)> {
    let rest = name.strip_prefix("texture-")?.strip_suffix(".png")?;
    let (i, j) = rest.split_once('-')?;
    Some((i.parse().ok()?, j.parse().ok()?))
}
