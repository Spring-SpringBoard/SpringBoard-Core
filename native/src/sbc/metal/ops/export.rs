use log::error;
use spring_native::prelude::NativeInterfaceRef;

use super::read::{map_size, METAL_RESOLUTION};

/// Builds a grayscale PNG of the live metal map, mapping `[0, 5.1]` metal onto
/// `[0, 255]`.
pub(crate) fn export(interface: &NativeInterfaceRef) -> Option<image::RgbImage> {
    let (size_x, size_z) = map_size(interface).or_else(|| {
        error!("export metal png: could not read map size");
        None
    })?;

    let width = size_x / METAL_RESOLUTION;
    let height = size_z / METAL_RESOLUTION;
    let metal = interface.metal_map();
    let mut image = image::RgbImage::new(width as u32, height as u32);
    for rx in 0..width {
        for rz in 0..height {
            let amount = metal.get_metal_amount(rx, rz).unwrap_or(0.0);
            let value = ((amount / 5.1).clamp(0.0, 1.0) * 255.0).round() as u8;
            image.put_pixel(rx as u32, rz as u32, image::Rgb([value, value, value]));
        }
    }
    Some(image)
}
