use spring_native::constants::GAME_SQUARE_SIZE;
use spring_native::prelude::NativeInterfaceRef;

use super::Heightmap;

const SQUARE_SIZE: f32 = GAME_SQUARE_SIZE as f32;

/// Heightmap grid point counts per axis, read from the engine.
pub(crate) fn dims(interface: &NativeInterfaceRef) -> Option<(usize, usize)> {
    if let Some((map_x, map_z)) = world_size(interface) {
        let square_size = usize::try_from(GAME_SQUARE_SIZE).ok()?;
        let points_x = map_x.checked_div(square_size)?.checked_add(1)?;
        let points_z = map_z.checked_div(square_size)?.checked_add(1)?;
        return Some((points_x, points_z));
    }

    let (points_x, points_z) = interface.terrain().get_height_map_size().ok()?;
    Some((points_x as usize, points_z as usize))
}

/// Current map dimensions in engine world units.
///
/// Terrain dimensions can remain stale for a frame after a map reload. The
/// game map info is owned by the active map and is therefore the authoritative
/// source when it is available.
pub(crate) fn world_size(interface: &NativeInterfaceRef) -> Option<(usize, usize)> {
    let info = interface.game().get_game_map_info_owned().ok()?;
    let map_square_size = usize::try_from(GAME_SQUARE_SIZE.checked_mul(64)?).ok()?;
    let map_x = usize::try_from(info.map_x)
        .ok()?
        .checked_mul(map_square_size)?;
    let map_z = usize::try_from(info.map_y)
        .ok()?
        .checked_mul(map_square_size)?;
    (map_x > 0 && map_z > 0).then_some((map_x, map_z))
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
