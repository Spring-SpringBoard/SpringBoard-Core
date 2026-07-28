//! Pure geometry used by the object brush and its preview.

pub(super) fn brush_count(size: f32, spread: f32) -> u32 {
    let density_area = (spread.max(1.0) * 100.0).max(1.0);
    ((size.max(1.0) * size.max(1.0)) / density_area)
        .ceil()
        .max(1.0) as u32
}

/// Lua's `sqrt(spread * 100) - tolerance`, with an empty radius treated as no
/// exclusion rather than accidentally querying a negative cylinder radius.
pub(super) fn feature_spacing(spread: f32) -> f32 {
    ((spread.max(0.0) * 100.0).sqrt() - 5.0).max(0.0)
}

/// Lua checks its not-yet-executed wait list at twice the engine query radius.
pub(super) fn pending_feature_conflict(
    pending: &[(f32, f32)],
    x: f32,
    z: f32,
    distance: f32,
) -> bool {
    let min_distance = distance * 2.0;
    let min_distance_sq = min_distance * min_distance;
    pending.iter().any(|(other_x, other_z)| {
        let dx = other_x - x;
        let dz = other_z - z;
        dx * dx + dz * dz < min_distance_sq
    })
}

pub(super) fn sunflower_point(index: u32, count: u32, radius: f32) -> (f32, f32) {
    if count <= 1 {
        return (0.0, 0.0);
    }
    const GOLDEN_ANGLE: f32 = 2.399_963_1;
    let t = index as f32 / (count - 1) as f32;
    let r = t.sqrt() * radius;
    let angle = index as f32 * GOLDEN_ANGLE;
    (r * angle.cos(), r * angle.sin())
}
