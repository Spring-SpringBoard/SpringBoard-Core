use log::{debug, error, info};

use super::read::{map_size, METAL_RESOLUTION};
use crate::sbc::sbc::SBC;

/// Writes a metal map (little-endian `f32` per cell) into the live engine.
pub(crate) fn write(sbc: &mut SBC, bytes: &[u8]) {
    let Some((size_x, size_z)) = map_size(sbc.interface()) else {
        error!("write metal map: could not read map size");
        return;
    };

    let expected = cell_count(size_x, size_z, METAL_RESOLUTION) * 4;
    if bytes.len() != expected {
        debug!(
            "skip metal map: file has {} bytes, current map expects {}",
            bytes.len(),
            expected
        );
        return;
    }

    let metal = sbc.interface().metal_map();
    let mut chunks = bytes.chunks_exact(4);
    let mut x = 0;
    while x < size_x {
        let rx = x / METAL_RESOLUTION;
        let mut z = 0;
        while z < size_z {
            let Some(chunk) = chunks.next() else {
                error!("write metal map: file ended before all cells were read");
                return;
            };
            let rz = z / METAL_RESOLUTION;
            let amount = f32::from_le_bytes([chunk[0], chunk[1], chunk[2], chunk[3]]);
            let _ = metal.set_metal_amount(rx, rz, amount);
            z += METAL_RESOLUTION;
        }
        x += METAL_RESOLUTION;
    }
    info!("metal map loaded");
}

fn cell_count(size_x: i32, size_z: i32, step: i32) -> usize {
    let count_x = (size_x + step - 1).div_euclid(step);
    let count_z = (size_z + step - 1).div_euclid(step);
    (count_x * count_z) as usize
}
