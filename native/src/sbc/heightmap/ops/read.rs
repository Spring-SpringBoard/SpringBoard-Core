use spring_native::constants::GAME_SQUARE_SIZE;
use spring_native::prelude::NativeInterfaceRef;

use super::Heightmap;

const SQUARE_SIZE: f32 = GAME_SQUARE_SIZE as f32;

/// Heightmap grid point counts per axis, read from the engine.
pub(crate) fn dims(interface: &NativeInterfaceRef) -> Option<(usize, usize)> {
    let (points_x, points_z) = interface.terrain().get_height_map_size().ok()?;
    Some((points_x as usize, points_z as usize))
}

/// Reads the live heightmap out of the engine.
pub(crate) fn read(interface: &NativeInterfaceRef) -> Option<Heightmap> {
    let (width, height) = dims(interface)?;
    let terrain = interface.terrain();
    let mut heights = Vec::with_capacity(width * height);
    for xi in 0..width {
        for zi in 0..height {
            let (x, z) = (xi as f32 * SQUARE_SIZE, zi as f32 * SQUARE_SIZE);
            heights.push(terrain.get_ground_height(x, z).unwrap_or(0.0));
        }
    }
    Some(Heightmap {
        width,
        height,
        heights,
    })
}
