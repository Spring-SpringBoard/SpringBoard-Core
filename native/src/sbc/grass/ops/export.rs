use log::error;
use spring_native::prelude::NativeInterfaceRef;

use super::read::{map_size, GRASS_STEP};

/// Builds a grayscale PNG image of the live grass map (255 = grass, 0 = none).
pub(crate) fn export(interface: &NativeInterfaceRef) -> Option<image::RgbImage> {
    let (size_x, size_z) = map_size(interface).or_else(|| {
        error!("export grass png: could not read map size");
        None
    })?;

    let width = size_x / GRASS_STEP;
    let height = size_z / GRASS_STEP;
    let terrain = interface.terrain();
    let mut image = image::RgbImage::new(width as u32, height as u32);
    for gx in 0..width {
        for gz in 0..height {
            let x = gx * GRASS_STEP;
            let z = gz * GRASS_STEP;
            let value = if terrain.get_grass(x as f32, z as f32).unwrap_or(0.0) > 0.0 {
                255
            } else {
                0
            };
            image.put_pixel(gx as u32, gz as u32, image::Rgb([value, value, value]));
        }
    }
    Some(image)
}
