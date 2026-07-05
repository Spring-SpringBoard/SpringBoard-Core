use std::path::Path;

/// Writes `bytes` to `path`, creating parent directories first.
pub(crate) fn write_bytes(path: &Path, bytes: &[u8]) -> Result<(), String> {
    ensure_parent(path)?;
    std::fs::write(path, bytes).map_err(|err| format!("write {}: {err}", path.display()))
}

/// Saves an image as PNG to `path`, creating parent directories first.
pub(crate) fn save_png(path: &Path, image: &image::RgbImage) -> Result<(), String> {
    ensure_parent(path)?;
    image
        .save(path)
        .map_err(|err| format!("write {}: {err}", path.display()))
}

/// Saves a 16-bit grayscale image as PNG to `path`, creating parent dirs first.
pub(crate) fn save_png16(
    path: &Path,
    image: &image::ImageBuffer<image::Luma<u16>, Vec<u16>>,
) -> Result<(), String> {
    ensure_parent(path)?;
    image
        .save(path)
        .map_err(|err| format!("write {}: {err}", path.display()))
}

fn ensure_parent(path: &Path) -> Result<(), String> {
    if let Some(parent) = path.parent() {
        std::fs::create_dir_all(parent)
            .map_err(|err| format!("create {}: {err}", parent.display()))?;
    }
    Ok(())
}
