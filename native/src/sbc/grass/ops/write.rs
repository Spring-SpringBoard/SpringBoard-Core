use log::{error, info};

use super::read::{map_size, GRASS_STEP};
use crate::sbc::sbc::SBC;

/// Writes a grass map (one `u8` per cell, `1` = grass) into the live engine.
pub(crate) fn write(sbc: &mut SBC, bytes: &[u8]) {
    let Some((size_x, size_z)) = map_size(sbc.interface()) else {
        error!("write grass map: could not read map size");
        return;
    };

    let synced = sbc.interface().synced_ctrl();
    let terrain = synced.terrain();
    let mut values = bytes.iter();
    let mut x = 0;
    while x < size_x {
        let mut z = 0;
        while z < size_z {
            let Some(value) = values.next() else {
                error!("write grass map: file ended before all cells were read");
                return;
            };
            if *value == 1 {
                let _ = terrain.add_grass(x as f32, z as f32);
            } else {
                let _ = terrain.remove_grass(x as f32, z as f32);
            }
            z += GRASS_STEP;
        }
        x += GRASS_STEP;
    }
    if values.next().is_some() {
        error!("write grass map: file has trailing bytes");
    }
    info!("grass map loaded");
}
