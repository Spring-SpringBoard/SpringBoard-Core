use super::Heightmap;

/// Decodes a `.data` heightmap of `width * height` little-endian `f32` values.
pub(crate) fn load(bytes: &[u8], width: usize, height: usize) -> Result<Heightmap, String> {
    let expected = width * height;
    if bytes.len() < expected * 4 {
        return Err(format!(
            "have {} bytes, expected at least {} ({} floats)",
            bytes.len(),
            expected * 4,
            expected
        ));
    }
    let mut heights = Vec::with_capacity(expected);
    for chunk in bytes.chunks_exact(4).take(expected) {
        heights.push(f32::from_le_bytes([chunk[0], chunk[1], chunk[2], chunk[3]]));
    }
    Ok(Heightmap {
        width,
        height,
        heights,
    })
}
