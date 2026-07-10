//! Drawing a selection marker on the ground under selected features and areas.
//!
//! Units already glow through the engine's own selection (mirrored in
//! `select_unit_array`); features and areas have no engine selection, so a ring
//! is drawn here in `draw_world`, as the Lua editor draws its own indicator.

use spring_native::prelude::NativeInterfaceRef;

const GL_LINE_LOOP: u32 = 0x0002;
/// Ground ring radius, in world units. A fixed size reads clearly without a
/// per-object radius binding.
const RING_RADIUS: f32 = 40.0;
const SEGMENTS: usize = 32;

/// Draw a ring on the ground at each position. Positions are world coordinates;
/// the ring is traced at the terrain height so it hugs slopes.
pub(crate) fn draw_selection(interface: &NativeInterfaceRef, positions: &[(f32, f32, f32)]) {
    if positions.is_empty() {
        return;
    }
    let gfx = interface.gfx();
    let terrain = interface.terrain();

    // Draw over the terrain regardless of depth, like a selection overlay.
    let _ = gfx.depth_test(false, false, 0);
    let _ = gfx.line_width(2.0);
    let _ = gfx.color(1.0, 0.85, 0.2, 0.9);

    for &(cx, _cy, cz) in positions {
        let _ = gfx.begin_end(GL_LINE_LOOP, || {
            for i in 0..SEGMENTS {
                let a = i as f32 / SEGMENTS as f32 * std::f32::consts::TAU;
                let x = cx + RING_RADIUS * a.cos();
                let z = cz + RING_RADIUS * a.sin();
                let y = terrain.get_ground_height(x, z).unwrap_or(0.0) + 2.0;
                let _ = gfx.vertex(x, y, z, 1.0, 3);
            }
        });
    }

    let _ = gfx.color(1.0, 1.0, 1.0, 1.0);
    let _ = gfx.line_width(1.0);
    let _ = gfx.depth_test(true, false, 0);
}
