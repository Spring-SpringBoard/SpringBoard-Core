//! Engine GL-primitive probes (render-to-texture, blit, custom shader pass).
//! These check the *engine*, not the paint feature. They stay here because the engine is built
//! in parallel and these isolate "is headless GL working at all" from paint bugs.

use std::cell::Cell;

use spring_native::prelude::{constants, sys};

use super::test_support::read_first_pixel;
use crate::sbc::tests::tests_api::TestCtx;
use crate::sbc::textures::model::graphics;

fn engine_gfx_render_readback(ctx: &mut TestCtx) -> Result<(), String> {
    let gfx = ctx.sbc.interface().gfx();

    let params = sys::GfxTextureParams {
        fbo: true,
        ..Default::default()
    };
    let name = gfx
        .create_texture(4, 4, 1, params)
        .map_err(|e| format!("create_texture: {e:?}"))?
        .ok_or("create_texture returned no name")?;

    let pixel: Cell<Option<(f32, f32, f32)>> = Cell::new(None);
    let read_err: Cell<Option<String>> = Cell::new(None);

    gfx.render_to_texture(&name, || {
        let _ = gfx.clear(constants::GL_COLOR_BUFFER_BIT, [0.0, 1.0, 0.0, 1.0], 4);
        match gfx.read_pixels(0, 0, 4, 4, constants::GL_RGBA) {
            Ok((values, components)) => {
                if components as usize >= 3 && !values.is_empty() {
                    pixel.set(Some((values[0], values[1], values[2])));
                } else {
                    read_err.set(Some(format!(
                        "read_pixels: {} values, {components} components",
                        values.len()
                    )));
                }
            }
            Err(e) => read_err.set(Some(format!("read_pixels: {e:?}"))),
        }
    })
    .map_err(|e| format!("render_to_texture: {e:?}"))?;

    let _ = gfx.delete_texture(&name);

    if let Some(e) = read_err.take() {
        return Err(e);
    }
    match pixel.get() {
        None => Err("no pixel read back (no GL context in headless boot?)".to_string()),
        Some((r, g, b)) if g > 0.5 && r < 0.5 && b < 0.5 => Ok(()),
        Some((r, g, b)) => Err(format!("first pixel = ({r},{g},{b}), expected green")),
    }
}

fn engine_gfx_blit(ctx: &mut TestCtx) -> Result<(), String> {
    let interface = *ctx.sbc.interface();
    let src = graphics::create_fbo_texture(&interface, 4, 4).ok_or("create src texture failed")?;
    let dst = graphics::create_fbo_texture(&interface, 4, 4).ok_or("create dst texture failed")?;

    let gfx = interface.gfx();
    gfx.render_to_texture(&src, || {
        let _ = gfx.clear(constants::GL_COLOR_BUFFER_BIT, [0.0, 1.0, 0.0, 1.0], 4);
    })
    .map_err(|e| format!("fill src: {e:?}"))?;

    graphics::blit(&interface, &src, &dst);

    let result = read_first_pixel(ctx, &dst);
    let _ = interface.gfx().delete_texture(&src);
    let _ = interface.gfx().delete_texture(&dst);

    match result {
        Some((r, g, b)) if g > 0.5 && r < 0.5 && b < 0.5 => Ok(()),
        Some((r, g, b)) => Err(format!(
            "dst pixel = ({r},{g},{b}), expected green after blit"
        )),
        None => Err("could not read dst after blit".to_string()),
    }
}

fn engine_gfx_shader_pass(ctx: &mut TestCtx) -> Result<(), String> {
    let interface = *ctx.sbc.interface();
    let gfx = interface.gfx();

    let frag = "void main(void) { gl_FragColor = vec4(1.0, 0.0, 0.0, 1.0); }";
    let (shader, _log_id) = gfx
        .create_shader("", "", "", "", "", frag, "", false, 0, false, 0, false, 0)
        .map_err(|e| format!("create_shader: {e:?}"))?;
    if shader == 0 {
        let log = gfx.get_shader_log().ok().flatten().unwrap_or_default();
        return Err(format!("shader failed to compile: {log}"));
    }

    let params = sys::GfxTextureParams {
        fbo: true,
        ..Default::default()
    };
    let tex = gfx
        .create_texture(4, 4, 1, params)
        .map_err(|e| format!("create_texture: {e:?}"))?
        .ok_or("create_texture returned no name")?;

    let pixel: Cell<Option<(f32, f32, f32)>> = Cell::new(None);
    gfx.render_to_texture(&tex, || {
        let _ = gfx.use_shader(shader);
        let _ = gfx.begin_end(constants::GL_QUADS, || {
            let _ = gfx.vertex(-1.0, -1.0, 0.0, 1.0, 2);
            let _ = gfx.vertex(-1.0, 1.0, 0.0, 1.0, 2);
            let _ = gfx.vertex(1.0, 1.0, 0.0, 1.0, 2);
            let _ = gfx.vertex(1.0, -1.0, 0.0, 1.0, 2);
        });
        let _ = gfx.use_shader(0);
        if let Ok((v, c)) = gfx.read_pixels(0, 0, 4, 4, constants::GL_RGBA) {
            if c as usize >= 3 && v.len() >= 3 {
                pixel.set(Some((v[0], v[1], v[2])));
            }
        }
    })
    .map_err(|e| format!("render_to_texture: {e:?}"))?;

    let _ = gfx.delete_texture(&tex);
    let _ = gfx.delete_shader(shader);

    match pixel.get() {
        Some((r, g, b)) if r > 0.5 && g < 0.5 && b < 0.5 => Ok(()),
        Some((r, g, b)) => Err(format!("pixel = ({r},{g},{b}), expected red from shader")),
        None => Err("no pixel read back after shader pass".to_string()),
    }
}

crate::integration_test!("engine_gfx_render_readback", engine_gfx_render_readback);
crate::integration_test!("engine_gfx_blit", engine_gfx_blit);
crate::integration_test!("engine_gfx_shader_pass", engine_gfx_shader_pass);
