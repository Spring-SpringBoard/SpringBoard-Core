//! Shared helpers for the texture-slice tests. Raw GL primitives are probed
//! separately in `test_engine_gfx`; here we test the painting API.

use std::cell::Cell;

use spring_native::prelude::constants;

use crate::sbc::tests::tests_api::TestCtx;
use crate::sbc::textures::model::graphics::{self, Texture};
use crate::sbc::textures::model::texture_model::{RegionTile, TextureModel};

/// Generate the editable tiles + shading textures (idempotent).
pub(crate) fn generate(ctx: &mut TestCtx) {
    let m = ctx.sbc.model::<TextureModel>();
    m.tiles.generate();
    m.shading.generate_all();
}

/// Fetch the tiles overlapping a region, backing them up into the stroke.
pub(crate) fn back_up_region(
    ctx: &mut TestCtx,
    sx: f32,
    sz: f32,
    ex: f32,
    ez: f32,
) -> Vec<RegionTile> {
    let m = ctx.sbc.model::<TextureModel>();
    m.history.back_up_region(&m.tiles, sx, sz, ex, ez)
}

/// One pixel (RGB) of an FBO texture; `None` on GL error. Must read inside the
/// `render_to_texture` callback (the FBO has to be bound).
pub(crate) fn read_pixel(ctx: &TestCtx, name: &str, x: i32, y: i32) -> Option<(f32, f32, f32)> {
    read_pixel_rgba(ctx, name, x, y).map(|v| (v.0, v.1, v.2))
}

pub(crate) fn read_pixel_rgba(
    ctx: &TestCtx,
    name: &str,
    x: i32,
    y: i32,
) -> Option<(f32, f32, f32, f32)> {
    let gfx = ctx.sbc.interface().gfx();
    let out: Cell<Option<(f32, f32, f32, f32)>> = Cell::new(None);
    gfx.render_to_texture(name, || {
        if let Ok((v, c)) = gfx.read_pixels(x, y, 1, 1, constants::GL_RGBA) {
            if c as usize >= 4 && v.len() >= 4 {
                out.set(Some((v[0], v[1], v[2], v[3])));
            }
        }
    })
    .ok()?;
    out.get()
}

pub(crate) fn read_first_pixel(ctx: &TestCtx, name: &str) -> Option<(f32, f32, f32)> {
    read_pixel(ctx, name, 0, 0)
}

/// The whole `w`x`h` RGBA buffer of a texture.
pub(crate) fn read_texture_rgba(ctx: &TestCtx, name: &str, w: i32, h: i32) -> Option<Vec<f32>> {
    let gfx = ctx.sbc.interface().gfx();
    let out: Cell<Option<Vec<f32>>> = Cell::new(None);
    gfx.render_to_texture(name, || {
        if let Ok((v, _)) = gfx.read_pixels(0, 0, w, h, constants::GL_RGBA) {
            out.set(Some(v));
        }
    })
    .ok()?;
    out.take()
}

/// Whether any component of any pixel differs beyond GL readback noise.
pub(crate) fn buffers_differ(a: &[f32], b: &[f32]) -> bool {
    a.len() != b.len() || a.iter().zip(b).any(|(x, y)| (x - y).abs() >= 0.02)
}

pub(crate) fn fill(ctx: &TestCtx, name: &str, rgba: [f32; 4]) {
    let gfx = ctx.sbc.interface().gfx();
    let _ = gfx.render_to_texture(name, || {
        let _ = gfx.clear(constants::GL_COLOR_BUFFER_BIT, rgba, 4);
    });
}

/// 4x4 FBO texture filled with `rgba`.
pub(crate) fn make_filled_texture(ctx: &TestCtx, rgba: [f32; 4]) -> Option<Texture> {
    let interface = *ctx.sbc.interface();
    let tex = graphics::create_fbo_texture(&interface, 4, 4)?;
    fill(ctx, &tex, rgba);
    Some(tex)
}

pub(crate) fn bind_engine_shading_texture(
    ctx: &TestCtx,
    bind_type: &str,
    slot: i32,
    rgba: [f32; 4],
) -> Option<Texture> {
    let interface = *ctx.sbc.interface();
    let tex = graphics::create_fbo_texture(&interface, 256, 256)?;
    fill(ctx, &tex, rgba);
    match interface
        .unsynced_ctrl()
        .set_map_shading_texture(bind_type, &tex, slot)
    {
        Ok(true) => Some(tex),
        _ => {
            let _ = interface.gfx().delete_texture(&tex);
            None
        }
    }
}

/// Approximate RGB equality (GL readback isn't bit-exact).
pub(crate) fn approx_eq(a: (f32, f32, f32), b: (f32, f32, f32)) -> bool {
    (a.0 - b.0).abs() < 0.02 && (a.1 - b.1).abs() < 0.02 && (a.2 - b.2).abs() < 0.02
}

/// One direct-manager stroke on tile (0,0): back up, overwrite with `color`,
/// close. Deterministic colours for the undo/redo ladder tests (no shader).
pub(crate) fn fill_stroke(ctx: &mut TestCtx, tile: &str, color: [f32; 4]) -> (f32, f32, f32) {
    let _ = back_up_region(ctx, 0.0, 0.0, 0.0, 0.0);
    fill(ctx, tile, color);
    ctx.sbc.model::<TextureModel>().history.push_stack(None);
    read_first_pixel(ctx, tile).unwrap_or((-1.0, -1.0, -1.0))
}

/// Parent of `SBC_TEST_RESULTS`, where PNG artifacts shared with Python land.
pub(crate) fn artifact_dir() -> std::path::PathBuf {
    let results = std::env::var("SBC_TEST_RESULTS").unwrap_or_else(|_| ".".to_string());
    std::path::Path::new(&results)
        .parent()
        .unwrap_or_else(|| std::path::Path::new("."))
        .to_path_buf()
}

/// Save an FBO texture as a PNG via `Gfx::save_image` (inside `render_to_texture`
/// so the FBO colour attachment is the readback source).
pub(crate) fn save_texture_png(
    ctx: &TestCtx,
    tex: &str,
    width: i32,
    height: i32,
    path: &std::path::Path,
) -> Result<(), String> {
    let gfx = ctx.sbc.interface().gfx();
    let path_s = path.to_str().ok_or("non-utf8 png path")?;
    let err: Cell<Option<String>> = Cell::new(None);
    gfx.render_to_texture(tex, || {
        match gfx.save_image(
            0,
            0,
            width,
            height,
            path_s,
            spring_native::GfxSaveImageOptions {
                alpha: true,
                yflip: false,
                grayscale16bit: false,
            },
            0,
        ) {
            Ok(true) => {}
            Ok(false) => err.set(Some("save_image returned false".to_string())),
            Err(e) => err.set(Some(format!("save_image: {e:?}"))),
        }
    })
    .map_err(|e| format!("render_to_texture: {e:?}"))?;
    if let Some(e) = err.into_inner() {
        return Err(e);
    }
    if !path.is_file() {
        return Err(format!("save_image did not produce {path:?}"));
    }
    if std::fs::metadata(path).map(|m| m.len()).unwrap_or(0) < 100 {
        return Err(format!("{path:?} too small to be a real PNG"));
    }
    Ok(())
}
