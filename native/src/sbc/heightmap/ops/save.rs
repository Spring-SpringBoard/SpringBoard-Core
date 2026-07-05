/// Encodes heights as raw little-endian `f32` per grid point (the `.data` form).
pub(crate) fn save(heights: &[f32]) -> Vec<u8> {
    let mut bytes = Vec::with_capacity(heights.len() * 4);
    for h in heights {
        bytes.extend_from_slice(&h.to_le_bytes());
    }
    bytes
}
