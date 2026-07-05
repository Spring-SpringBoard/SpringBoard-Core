use std::collections::HashMap;

use crate::sbc::hashable_float::HashableFloat;

use crate::sbc::heightmap::model::terrain_manager::GreyscaleShape;

// Convoluted legacy Springboard behavior.
// TODO:
// - Do not use nested hashmaps
// - Return a Vector rather than a HashMap. In generally,
// convert the whole system to use the far more efficient vectors.
pub type Maps = HashMap<
    String,
    HashMap<usize, HashMap<HashableFloat, HashMap<HashableFloat, HashMap<usize, f32>>>>,
>;

pub fn get_map(
    size: usize,
    delta: f32,
    shape_name: &str,
    rotation: f32,
    orig_size: f32,
    maps: &mut Maps,
    greyscale: &GreyscaleShape,
) -> HashMap<usize, f32> {
    maps.entry(shape_name.to_string())
        .or_default()
        .entry(size)
        .or_default()
        .entry(HashableFloat(rotation))
        .or_default()
        .entry(HashableFloat(delta))
        .or_insert_with(|| generate_map(size, delta, rotation, orig_size, greyscale))
        .clone()
}

fn generate_map(
    size: usize,
    delta: f32,
    rotation: f32,
    orig_size: f32,
    greyscale: &GreyscaleShape,
) -> HashMap<usize, f32> {
    let size_f32 = size as f32;
    let size_x = greyscale.size_x;
    let size_z = greyscale.size_z;
    let mut map = HashMap::new();
    let res = &greyscale.res;

    let scale_x = size_x as f32 / size_f32;
    let scale_z = size_z as f32 / size_f32;
    let parts = size / Game::SQUARE_SIZE + 1;

    let get_index = |x: f32, z: f32| -> usize {
        let rx = (scale_x * x).floor().max(0.0).min((size_x - 1) as f32) as usize;
        let rz = (scale_z * z).floor().max(0.0).min((size_z - 1) as f32) as usize;
        rx * size_x + rz
    };

    let interpolate = |x: f32, z: f32| -> f32 {
        let rx_raw = scale_x * x;
        let rz_raw = scale_z * z;
        let rx = rx_raw.floor() as usize;
        let rz = rz_raw.floor() as usize;
        let indx = rx * size_x + rz;

        let i = if rx_raw > rx as f32 { 1 } else { -1 };
        let j = if rz_raw > rz as f32 { 1 } else { -1 };
        let dx = 1.0 - (rx_raw - rx as f32);
        let dz = 1.0 - (rz_raw - rz as f32);

        res[indx] * dx * dz
            + res[(indx as i32 + i * size_x as i32) as usize] * (1.0 - dx) * dz
            + res[(indx as i32 + j) as usize] * dx * (1.0 - dz)
            + res[(indx as i32 + i * size_x as i32 + j) as usize] * (1.0 - dx) * (1.0 - dz)
    };

    let size_ratio = size_f32 / orig_size;
    let dsh = (size_f32 - orig_size) / 2.0;
    let sh = size_f32 / 2.0;

    for x in (0..=(size)).step_by(Game::SQUARE_SIZE) {
        for z in (0..=(size)).step_by(Game::SQUARE_SIZE) {
            let (mut rx, mut rz) = (x as f32, z as f32);
            rx -= sh;
            rz -= sh;
            (rx, rz) = rotate(rx, rz, rotation);
            rx += sh;
            rz += sh;
            rx *= size_ratio;
            rz *= size_ratio;
            rx -= dsh;
            rz -= dsh;

            let diff = if rx < 0.0
                || rz < 0.0
                || scale_x * rx > (size_x - 1) as f32
                || scale_z * rz > (size_z - 1) as f32
            {
                0.0
            } else {
                let indx = get_index(rx, rz);
                if indx > size_x + 1 && indx < size_x * (size_x - 1) - 1 {
                    interpolate(rx, rz)
                } else {
                    res[indx]
                }
            };

            map.insert(x + z * parts, diff * delta);
        }
    }

    map
}

fn rotate(x: f32, y: f32, rotation: f32) -> (f32, f32) {
    (
        x * rotation.cos() - y * rotation.sin(),
        x * rotation.sin() + y * rotation.cos(),
    )
}

struct Game;

impl Game {
    const SQUARE_SIZE: usize = 8;
}
