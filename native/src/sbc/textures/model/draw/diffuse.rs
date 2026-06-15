use spring_native::prelude::NativeInterfaceRef;

use crate::sbc::textures::model::graphics;
use crate::sbc::textures::model::texture_drawing::{
    apply_texture, generate_map_coords, generate_texture_coords,
};
use crate::sbc::textures::model::texture_model::TextureModel;

use super::options::{PaintOptions, Region};
use super::shared::{
    blend_mode_expr, set_diffuse_uniforms, set_region_uniforms, SHADER_PATH_DIFFUSE,
};

pub fn paint_diffuse(
    interface: &NativeInterfaceRef,
    tm: &mut TextureModel,
    region: Region,
    opts: &PaintOptions,
) {
    if !opts.diffuse_enabled {
        return;
    }
    let Some(brush_diffuse) = opts.brush_diffuse.as_ref() else {
        return;
    };
    let Some(shader) =
        tm.shaders
            .get_or_compile(interface, SHADER_PATH_DIFFUSE, blend_mode_expr(opts.mode))
    else {
        return;
    };

    let pattern = tm.cache.get(&opts.pattern_texture);
    let brush = tm.cache.get(brush_diffuse);
    let size = region.size;
    let t_coord = generate_texture_coords(region.x, region.z, size, size, &opts.tex_coord_opts());

    let tiles = tm.history.back_up_region(
        &tm.tiles,
        region.x,
        region.z,
        region.end_x(),
        region.end_z(),
    );
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
    let _ = gfx.bind_texture(&pattern, 1, true);
    let _ = gfx.bind_texture(&brush, 2, true);
    set_diffuse_uniforms(interface, &shader, opts);

    for (i, j, live, src, m_coord, v_coord) in jobs {
        let _ = gfx.use_shader(shader.shader);
        set_diffuse_uniforms(interface, &shader, opts);
        set_region_uniforms(interface, &shader, &m_coord);
        let _ = gfx.bind_texture(&src, 0, true);
        let _ = gfx.bind_texture(&pattern, 1, true);
        let _ = gfx.bind_texture(&brush, 2, true);
        let _ = gfx.render_to_texture(&live, || {
            apply_texture(interface, &m_coord, &t_coord, &v_coord);
        });
        let _ = gfx.bind_texture(&src, 0, false);
        let _ = gfx.delete_texture(&src);
        tm.tiles.mark_dirty(i, j);
    }

    let _ = gfx.bind_texture(&pattern, 1, false);
    let _ = gfx.bind_texture(&brush, 2, false);
    let _ = gfx.use_shader(0);
}
