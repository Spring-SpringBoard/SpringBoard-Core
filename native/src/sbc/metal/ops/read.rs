use spring_native::prelude::NativeInterfaceRef;

/// Map units per metal-map cell. The metal map is `mapSize / METAL_RESOLUTION`
/// cells per axis (`save_command.lua`'s `METAL_RESOLUTION`).
pub(crate) const METAL_RESOLUTION: i32 = 16;

/// Reads the live metal map: little-endian `f32` per cell, row-major.
pub(crate) fn read(interface: &NativeInterfaceRef) -> Option<Vec<u8>> {
    let (size_x, size_z) = map_size(interface)?;
    let metal = interface.metal_map();
    let mut bytes = Vec::new();
    let mut x = 0;
    while x < size_x {
        let rx = x / METAL_RESOLUTION;
        let mut z = 0;
        while z < size_z {
            let rz = z / METAL_RESOLUTION;
            let amount = metal.get_metal_amount(rx, rz).unwrap_or(0.0);
            bytes.extend_from_slice(&amount.to_le_bytes());
            z += METAL_RESOLUTION;
        }
        x += METAL_RESOLUTION;
    }
    Some(bytes)
}

pub(crate) fn map_size(interface: &NativeInterfaceRef) -> Option<(i32, i32)> {
    let (mmx, mmz) = interface.metal_map().get_metal_map_size().ok()?;
    Some((mmx * METAL_RESOLUTION, mmz * METAL_RESOLUTION))
}
