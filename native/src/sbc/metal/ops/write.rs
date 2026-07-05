use log::{error, info};

use super::read::{map_size, METAL_RESOLUTION};
use crate::sbc::sbc::SBC;

/// Writes a metal map (little-endian `f32` per cell) into the live engine.
pub(crate) fn write(sbc: &mut SBC, bytes: &[u8]) {
    let Some((size_x, size_z)) = map_size(sbc.interface()) else {
        error!("write metal map: could not read map size");
        return;
    };

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
    if !chunks.remainder().is_empty() || chunks.next().is_some() {
        error!("write metal map: file has trailing bytes");
    }
    info!("metal map loaded");
}
