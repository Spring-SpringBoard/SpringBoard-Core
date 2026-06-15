use spring_native::prelude::NativeInterfaceRef;

use crate::sbc::textures::model::graphics;
use crate::sbc::textures::model::texture_drawing::{apply_texture_dnts, generate_map_coords};
use crate::sbc::textures::model::texture_model::TextureModel;

use super::options::{PaintOptions, Region};
use super::shared::{map_size, set_region_uniforms, SHADER_PATH_DNTS};

pub fn paint_dnts(
    interface: &NativeInterfaceRef,
    tm: &mut TextureModel,
    region: Region,
    opts: &PaintOptions,
) {
    let (x, z, size) = (region.x, region.z, region.size);
    let Some(shader) = tm.shaders.get_or_compile(interface, SHADER_PATH_DNTS, "") else {
        return;
    };
    let Some((map_size_x, map_size_z)) = map_size(interface) else {
        return;
    };

    let ty = "splat_distr";
    let ready = match opts.shading_source_for(ty) {
        Some(source) => tm.shading.ensure(ty, Some(source)),
        None => tm.shading.ensure(ty, None),
    };
    if !ready {
        log::debug!("paint_dnts: no {ty} shading texture");
        return;
    }
    if let Some(surface) = tm.shading.surface(ty).cloned() {
        tm.history.backup(&surface);
    }
    let Some(target) = tm.shading.texture(ty).map(|t| t.texture.clone()) else {
        return;
    };

    let size_x = size / map_size_x as f32;
    let size_z = size / map_size_z as f32;
    let mx = x / map_size_x as f32;
    let mz = z / map_size_z as f32;
    let (m_coord, v_coord) = generate_map_coords(mx, mz, size_x, size_z);

    let pattern = tm.cache.get(&opts.pattern_texture);

    let Some(src) = graphics::copy_texture(interface, &target) else {
        return;
    };

    let gfx = interface.gfx();
    let _ = gfx.blending(false);
    let _ = gfx.use_shader(shader.shader);

    if shader.uniforms.strength >= 0 {
        let _ = gfx.uniform(shader.uniforms.strength, [opts.strength, 0.0, 0.0, 0.0], 1);
    }
    if shader.uniforms.color_index >= 0 {
        let _ = gfx.uniform_int(shader.uniforms.color_index, [opts.color_index, 0, 0, 0], 1);
    }
    if shader.uniforms.exclusive >= 0 {
        let _ = gfx.uniform_int(shader.uniforms.exclusive, [opts.exclusive, 0, 0, 0], 1);
    }
    if shader.uniforms.value >= 0 {
        let _ = gfx.uniform(shader.uniforms.value, [opts.value, 0.0, 0.0, 0.0], 1);
    }
    if shader.uniforms.pattern_rotation >= 0 {
        let _ = gfx.uniform(
            shader.uniforms.pattern_rotation,
            [opts.pattern_rotation, 0.0, 0.0, 0.0],
            1,
        );
    }
    set_region_uniforms(interface, &shader, &m_coord);

    let _ = gfx.bind_texture(&src, 0, true);
    let _ = gfx.bind_texture(&pattern, 1, true);
    let _ = gfx.render_to_texture(&target, || {
        apply_texture_dnts(interface, &m_coord, &v_coord);
    });
    let _ = gfx.bind_texture(&src, 0, false);
    let _ = gfx.delete_texture(&src);
    let _ = gfx.bind_texture(&pattern, 1, false);
    let _ = gfx.use_shader(0);
    tm.shading.mark_dirty(ty);
}
