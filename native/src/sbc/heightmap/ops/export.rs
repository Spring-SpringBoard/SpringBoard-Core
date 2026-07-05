use super::Heightmap;

/// A 16-bit grayscale image, the format heightmaps export to.
pub(crate) type Png16 = image::ImageBuffer<image::Luma<u16>, Vec<u16>>;

/// Renders a heightmap as a 16-bit grayscale PNG image, normalizing `[min, max]`.
pub(crate) fn export(map: &Heightmap, min: f32, max: f32) -> Png16 {
    let span = (max - min).max(f32::EPSILON);
    let mut img = Png16::new(map.width as u32, map.height as u32);
    let mut i = 0;
    for xi in 0..map.width {
        for zi in 0..map.height {
            if i >= map.heights.len() {
                break;
            }
            let norm = ((map.heights[i] - min) / span).clamp(0.0, 1.0);
            img.put_pixel(
                xi as u32,
                zi as u32,
                image::Luma([(norm * 65535.0).round() as u16]),
            );
            i += 1;
        }
    }
    img
}

/// The `(min, max)` of `heights`, for auto-ranging a PNG export.
pub(crate) fn extremes(heights: &[f32]) -> (f32, f32) {
    heights
        .iter()
        .copied()
        .fold((f32::INFINITY, f32::NEG_INFINITY), |(min, max), h| {
            (min.min(h), max.max(h))
        })
}
