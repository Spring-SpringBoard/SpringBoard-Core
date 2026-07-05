use spring_native::constants::GAME_SQUARE_SIZE;
use spring_native::prelude::NativeInterfaceRef;

use super::Heightmap;

const SQUARE_SIZE: f32 = GAME_SQUARE_SIZE as f32;

/// Writes a heightmap into the engine and recalculates the rendered surface.
pub(crate) fn write(interface: &NativeInterfaceRef, map: &Heightmap) {
    let synced = interface.synced_ctrl();
    let terrain = synced.terrain();
    // `set_height_map` alone mutates data without recalculating the rendered
    // terrain. The function wrapper is what makes the surface visibly update.
    let _ = terrain.set_height_map_func(|| {
        let mut i = 0;
        for xi in 0..map.width {
            for zi in 0..map.height {
                if i >= map.heights.len() {
                    break;
                }
                let (x, z) = (xi as f32 * SQUARE_SIZE, zi as f32 * SQUARE_SIZE);
                let _ = terrain.set_height_map(x, z, map.heights[i], 1.0);
                i += 1;
            }
        }
    });
}
