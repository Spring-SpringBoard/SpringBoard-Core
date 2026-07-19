use spring_native::prelude::NativeInterfaceRef;

use crate::sbc::textures::model::graphics;
use crate::sbc::textures::model::texture_drawing::{
    apply_texture, generate_map_coords, generate_texture_coords,
};
use crate::sbc::textures::model::texture_model::TextureModel;

use super::options::{KernelMode, PaintOptions, Region};
use super::shared::{kernel_for, SHADER_PATH_FILTER};

pub fn paint_filter(
    interface: &NativeInterfaceRef,
    tm: &mut TextureModel,
    region: Region,
    opts: &PaintOptions,
) {
    let (start_x, start_z, end_x, end_z) = (region.x, region.z, region.end_x(), region.end_z());
    let Some(shader) = tm.shaders.get_or_compile(interface, SHADER_PATH_FILTER, "") else {
        return;
    };

    let pattern = tm.cache.get(&opts.pattern_texture);

    let size = end_x - start_x;
    let t_coord = generate_texture_coords(start_x, start_z, size, size, &opts.tex_coord_opts());
    let tiles = tm
        .history
        .back_up_region(&tm.tiles, start_x, start_z, end_x, end_z);
    let mut jobs = Vec::new();
    for tile in tiles {
        let (m_coord, v_coord) = generate_map_coords(tile.offset_x, tile.offset_z, size, size);
        let live = tile.texture.clone();
        let Some(src) = graphics::copy_texture(interface, &live) else {
            continue;
        };
        jobs.push((tile.i, tile.j, live, src, m_coord, v_coord));
    }

    let gfx = interface.gfx();
    let _ = gfx.blending(false);
    let _ = gfx.use_shader(shader.shader);

    if shader.uniforms.kernel >= 0 {
        let kernel = kernel_for(opts.kernel_mode);
        let _ = gfx.uniform_matrix(shader.uniforms.kernel, &kernel, false);
    }
    if shader.uniforms.kernel_scale >= 0 {
        // A 3x3 tap one texel apart is invisible on a high-resolution tile;
        // the blur brush widens its radius with strength. Edge kernels
        // (sobel, outline, sharpen) keep true 1-texel taps.
        let scale = match opts.kernel_mode {
            KernelMode::Blur => 1.0 + opts.strength * 3.0,
            _ => 1.0,
        };
        let _ = gfx.uniform(shader.uniforms.kernel_scale, [scale, 0.0, 0.0, 0.0], 1);
    }
    if shader.uniforms.strength >= 0 {
        let _ = gfx.uniform(shader.uniforms.strength, [opts.strength, 0.0, 0.0, 0.0], 1);
    }
    if shader.uniforms.pattern_rotation >= 0 {
        let _ = gfx.uniform(
            shader.uniforms.pattern_rotation,
            [opts.pattern_rotation, 0.0, 0.0, 0.0],
            1,
        );
    }
    let _ = gfx.bind_texture(&pattern, 1, true);

    for (i, j, live, src, m_coord, v_coord) in jobs {
        let _ = gfx.use_shader(shader.shader);
        let _ = gfx.bind_texture(&src, 0, true);
        let _ = gfx.bind_texture(&pattern, 1, true);
        let _ = gfx.render_to_texture(&live, || {
            apply_texture(interface, &m_coord, &t_coord, &v_coord);
        });
        let _ = gfx.bind_texture(&src, 0, false);
        let _ = gfx.delete_texture(&src);
        tm.tiles.mark_dirty(i, j);
    }

    let _ = gfx.bind_texture(&pattern, 1, false);
    let _ = gfx.use_shader(0);
}
