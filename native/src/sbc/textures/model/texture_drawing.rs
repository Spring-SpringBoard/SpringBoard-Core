//! Coord generators and QUADS draw helpers used by the paint modes.
//!
//! Each pass renders one full quad per map tile. The four `MultiTexCoord`
//! channels feed (in this order):
//!   - 0: map coords (mCoord), the fragment shader's `mapTex` sampler
//!   - 1: brush-local coords, constant per corner, for the pattern sampler
//!   - 2: rotated texture coords (tCoord), brush/pattern UV
//!   - 3: heightmap coords (hCoord, height pass only)

use spring_native::prelude::{constants, NativeInterfaceRef};

#[derive(Default, Clone, Copy)]
pub struct TexCoordOpts {
    pub tex_offset_x: f32,
    pub tex_offset_y: f32,
    pub tex_scale: f32,
    pub rotation: f32,
}

/// Returns (mCoord, vCoord): both are 8 floats laid out as
/// `[x0,z0, x1,z1, x2,z2, x3,z3]` for QUADS corners (clockwise from BL).
/// `vCoord` is `mCoord * 2 - 1` (i.e. NDC).
pub fn generate_map_coords(mx: f32, mz: f32, m_size_x: f32, m_size_z: f32) -> ([f32; 8], [f32; 8]) {
    let m_coord = [
        mx,
        mz,
        mx,
        mz + m_size_z,
        mx + m_size_x,
        mz + m_size_z,
        mx + m_size_x,
        mz,
    ];
    let mut v_coord = [0.0; 8];
    for i in 0..8 {
        v_coord[i] = m_coord[i] * 2.0 - 1.0;
    }
    (m_coord, v_coord)
}

/// Brush texture coords with the same corner layout.
pub fn generate_texture_coords(
    x: f32,
    z: f32,
    size_x: f32,
    size_z: f32,
    opts: &TexCoordOpts,
) -> [f32; 8] {
    let mut t_coord = [x, z, x, z + size_z, x + size_x, z + size_z, x + size_x, z];

    if opts.tex_offset_x != 0.0 || opts.tex_offset_y != 0.0 {
        offset_coords(
            &mut t_coord,
            opts.tex_offset_x * size_x,
            opts.tex_offset_y * size_z,
        );
    }
    if opts.tex_scale != 0.0 && opts.tex_scale != 1.0 {
        scale_coords(&mut t_coord, opts.tex_scale, opts.tex_scale);
    }
    if opts.rotation != 0.0 {
        rotate_coords(&mut t_coord, opts.rotation);
    }
    t_coord
}

fn offset_coords(t: &mut [f32; 8], dx: f32, dy: f32) {
    for i in (0..8).step_by(2) {
        t[i] += dx;
        t[i + 1] += dy;
    }
}

fn scale_coords(t: &mut [f32; 8], sx: f32, sy: f32) {
    for i in (0..8).step_by(2) {
        t[i] *= sx;
        t[i + 1] *= sy;
    }
}

/// Rotate around the rectangle's centre while preserving the existing corner
/// offset convention.
fn rotate_coords(t: &mut [f32; 8], angle: f32) {
    let (s, c) = (angle.sin(), angle.cos());
    let tdx = t[4] - t[0];
    let tdz = t[3] - t[1];
    for i in (0..8).step_by(2) {
        let x = t[i] - tdx;
        let y = t[i + 1] - tdz;
        t[i] = x * c - y * s + tdx;
        t[i + 1] = x * s + y * c + tdz;
    }
}

/// Issue a QUADS draw with MultiTexCoord channels 0..2 set per corner. Channel
/// 1 is the brush-local UV `(0,0) (0,1) (1,1) (1,0)`.
pub fn apply_texture(interface: &NativeInterfaceRef, m: &[f32; 8], t: &[f32; 8], v: &[f32; 8]) {
    let gfx = interface.gfx();
    let _ = gfx.begin_end(constants::GL_QUADS, || {
        emit_corner(interface, m[0], m[1], 0.0, 0.0, t[0], t[1], v[0], v[1]);
        emit_corner(interface, m[2], m[3], 0.0, 1.0, t[2], t[3], v[2], v[3]);
        emit_corner(interface, m[4], m[5], 1.0, 1.0, t[4], t[5], v[4], v[5]);
        emit_corner(interface, m[6], m[7], 1.0, 0.0, t[6], t[7], v[6], v[7]);
    });
}

/// QUADS draw with a 4th `MultiTexCoord` channel for the heightmap pass.
pub fn apply_texture_with_height(
    interface: &NativeInterfaceRef,
    m: &[f32; 8],
    t: &[f32; 8],
    v: &[f32; 8],
    h: &[f32; 8],
) {
    let gfx = interface.gfx();
    let _ = gfx.begin_end(constants::GL_QUADS, || {
        emit_corner_h(
            interface, m[0], m[1], 0.0, 0.0, t[0], t[1], h[0], h[1], v[0], v[1],
        );
        emit_corner_h(
            interface, m[2], m[3], 0.0, 1.0, t[2], t[3], h[2], h[3], v[2], v[3],
        );
        emit_corner_h(
            interface, m[4], m[5], 1.0, 1.0, t[4], t[5], h[4], h[5], v[4], v[5],
        );
        emit_corner_h(
            interface, m[6], m[7], 1.0, 0.0, t[6], t[7], h[6], h[7], v[6], v[7],
        );
    });
}

/// QUADS draw for DNTS / shading-only passes: only channels 0 and 1 are needed.
pub fn apply_texture_dnts(interface: &NativeInterfaceRef, m: &[f32; 8], v: &[f32; 8]) {
    let gfx = interface.gfx();
    let _ = gfx.begin_end(constants::GL_QUADS, || {
        let _ = gfx.multi_tex_coord(0, m[0], m[1], 0.0, 0.0, 2);
        let _ = gfx.multi_tex_coord(1, 0.0, 0.0, 0.0, 0.0, 2);
        let _ = gfx.vertex(v[0], v[1], 0.0, 1.0, 2);
        let _ = gfx.multi_tex_coord(0, m[2], m[3], 0.0, 0.0, 2);
        let _ = gfx.multi_tex_coord(1, 0.0, 1.0, 0.0, 0.0, 2);
        let _ = gfx.vertex(v[2], v[3], 0.0, 1.0, 2);
        let _ = gfx.multi_tex_coord(0, m[4], m[5], 0.0, 0.0, 2);
        let _ = gfx.multi_tex_coord(1, 1.0, 1.0, 0.0, 0.0, 2);
        let _ = gfx.vertex(v[4], v[5], 0.0, 1.0, 2);
        let _ = gfx.multi_tex_coord(0, m[6], m[7], 0.0, 0.0, 2);
        let _ = gfx.multi_tex_coord(1, 1.0, 0.0, 0.0, 0.0, 2);
        let _ = gfx.vertex(v[6], v[7], 0.0, 1.0, 2);
    });
}

#[allow(clippy::too_many_arguments)]
fn emit_corner(
    interface: &NativeInterfaceRef,
    m0: f32,
    m1: f32,
    p0: f32,
    p1: f32,
    t0: f32,
    t1: f32,
    v0: f32,
    v1: f32,
) {
    let gfx = interface.gfx();
    let _ = gfx.multi_tex_coord(0, m0, m1, 0.0, 0.0, 2);
    let _ = gfx.multi_tex_coord(1, p0, p1, 0.0, 0.0, 2);
    let _ = gfx.multi_tex_coord(2, t0, t1, 0.0, 0.0, 2);
    let _ = gfx.vertex(v0, v1, 0.0, 1.0, 2);
}

#[allow(clippy::too_many_arguments)]
fn emit_corner_h(
    interface: &NativeInterfaceRef,
    m0: f32,
    m1: f32,
    p0: f32,
    p1: f32,
    t0: f32,
    t1: f32,
    h0: f32,
    h1: f32,
    v0: f32,
    v1: f32,
) {
    let gfx = interface.gfx();
    let _ = gfx.multi_tex_coord(0, m0, m1, 0.0, 0.0, 2);
    let _ = gfx.multi_tex_coord(1, p0, p1, 0.0, 0.0, 2);
    let _ = gfx.multi_tex_coord(2, t0, t1, 0.0, 0.0, 2);
    let _ = gfx.multi_tex_coord(3, h0, h1, 0.0, 0.0, 2);
    let _ = gfx.vertex(v0, v1, 0.0, 1.0, 2);
}
