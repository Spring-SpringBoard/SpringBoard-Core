use spring_native::prelude::NativeInterfaceRef;

use crate::sbc::textures::model::graphics::{self, Texture};
use crate::sbc::textures::model::texture_drawing::{
    apply_texture, generate_map_coords, generate_texture_coords,
};
use crate::sbc::textures::model::texture_model::TextureModel;

use super::options::{PaintOptions, Region};
use super::shared::{
    blend_mode_expr, map_size, set_diffuse_uniforms, set_region_uniforms, SHADER_PATH_DIFFUSE,
};

/// Paint the enabled shading textures (specular / emission / … ) under the
/// brush. These cover the whole map, so the pass works in world-space.
pub fn paint_shading_textures(
    interface: &NativeInterfaceRef,
    tm: &mut TextureModel,
    region: Region,
    opts: &PaintOptions,
) {
    let (x, z, size) = (region.x, region.z, region.size);
    let Some(shader) =
        tm.shaders
            .get_or_compile(interface, SHADER_PATH_DIFFUSE, blend_mode_expr(opts.mode))
    else {
        return;
    };
    let Some((map_size_x, map_size_z)) = map_size(interface) else {
        return;
    };
    let map_size_x = map_size_x as f32;
    let map_size_z = map_size_z as f32;

    let pattern = tm.cache.get(&opts.pattern_texture);

    let size_x = size / map_size_x;
    let size_z = size / map_size_z;
    let ts = tm.tiles.texture_size() as f32;
    let t_coord =
        generate_texture_coords(x / ts, z / ts, size / ts, size / ts, &opts.tex_coord_opts());
    let (m_coord, v_coord) = generate_map_coords(x / map_size_x, z / map_size_z, size_x, size_z);

    let candidates: Vec<(String, Texture)> = opts
        .brush_shading
        .iter()
        .filter(|(ty, _)| opts.shading_enabled_for(ty))
        .cloned()
        .collect();

    let mut jobs = Vec::new();
    for (ty, brush_path) in candidates {
        let ready = match opts.shading_source_for(&ty) {
            Some(source) => tm.shading.ensure(&ty, Some(source)),
            None => tm.shading.ensure(&ty, None),
        };
        if !ready {
            continue;
        }
        if !opts.shading_enabled_for(&ty) {
            continue;
        }
        if let Some(surface) = tm.shading.surface(&ty).cloned() {
            tm.history.backup(&surface);
        }
        let Some(target) = tm.shading.texture(&ty).map(|t| t.texture) else {
            continue;
        };
        let brush = tm.cache.get(&brush_path);
        let Some(src) = graphics::copy_texture(interface, &target) else {
            continue;
        };
        jobs.push((ty, target, brush, src));
    }

    let gfx = interface.gfx();
    let _ = gfx.blending(false);
    let _ = gfx.use_shader(shader.shader);
    let _ = gfx.bind_texture(&pattern, 1, true);
    set_diffuse_uniforms(interface, &shader, opts);
    set_region_uniforms(interface, &shader, &m_coord);

    let mut bound_brush: Option<Texture> = None;
    for (ty, target, brush, src) in jobs {
        if bound_brush.as_ref() != Some(&brush) {
            let _ = gfx.bind_texture(&brush, 2, true);
            bound_brush = Some(brush.clone());
        }
        let _ = gfx.use_shader(shader.shader);
        set_diffuse_uniforms(interface, &shader, opts);
        set_region_uniforms(interface, &shader, &m_coord);
        let _ = gfx.bind_texture(&src, 0, true);
        let _ = gfx.bind_texture(&pattern, 1, true);
        let _ = gfx.bind_texture(&brush, 2, true);
        let _ = gfx.render_to_texture(&target, || {
            apply_texture(interface, &m_coord, &t_coord, &v_coord);
        });
        tm.shading.refresh_mipmap(&ty);
        let _ = gfx.bind_texture(&src, 0, false);
        let _ = gfx.delete_texture(&src);
        tm.shading.mark_dirty(&ty);
    }

    if let Some(brush) = bound_brush {
        let _ = gfx.bind_texture(&brush, 2, false);
    }
    let _ = gfx.bind_texture(&pattern, 1, false);
    let _ = gfx.use_shader(0);
}
