use spring_native::constants::GAME_SQUARE_SIZE;
use spring_native::prelude::NativeInterfaceRef;

pub(crate) const GRASS_STEP: i32 = GAME_SQUARE_SIZE * 4;

const MAP_UNITS_PER_METAL_CELL: i32 = 16;

/// Reads the live grass map: one `u8` per cell (`1` = grass, `0` = none),
/// row-major over the `GRASS_STEP` grid.
pub(crate) fn read(interface: &NativeInterfaceRef) -> Option<Vec<u8>> {
    let (size_x, size_z) = map_size(interface)?;
    let terrain = interface.terrain();
    let mut bytes = Vec::new();
    let mut x = 0;
    while x < size_x {
        let mut z = 0;
        while z < size_z {
            let grass = terrain.get_grass(x as f32, z as f32).unwrap_or(0.0);
            bytes.push(grass as u8);
            z += GRASS_STEP;
        }
        x += GRASS_STEP;
    }
    Some(bytes)
}

pub(crate) fn map_size(interface: &NativeInterfaceRef) -> Option<(i32, i32)> {
    let (mmx, mmz) = interface.metal_map().get_metal_map_size().ok()?;
    Some((
        mmx * MAP_UNITS_PER_METAL_CELL,
        mmz * MAP_UNITS_PER_METAL_CELL,
    ))
}
