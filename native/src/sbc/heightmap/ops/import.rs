use std::path::Path;

use super::Heightmap;

/// Imports a grayscale PNG into a `width * height` heightmap, mapping luminance
/// back onto `[min, max]`. Resamples only when the source grid differs, so a
/// matching-size import is exact (no interpolation smear).
pub(crate) fn import(
    path: &Path,
    width: usize,
    height: usize,
    min: f32,
    max: f32,
) -> Result<Heightmap, String> {
    let img = image::open(path).map_err(|err| format!("decode {}: {err}", path.display()))?;
    let luma = img.to_luma16();
    let scaled = if luma.dimensions() == (width as u32, height as u32) {
        luma
    } else {
        image::imageops::resize(
            &luma,
            width as u32,
            height as u32,
            image::imageops::FilterType::Triangle,
        )
    };
    let span = max - min;
    let mut heights = Vec::with_capacity(width * height);
    for xi in 0..width {
        for zi in 0..height {
            let lum = scaled.get_pixel(xi as u32, zi as u32).0[0] as f32 / 65535.0;
            heights.push(min + lum * span);
        }
    }
    Ok(Heightmap {
        width,
        height,
        heights,
    })
}
