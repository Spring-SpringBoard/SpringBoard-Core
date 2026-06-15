use spring_native::prelude::NativeInterfaceRef;

use super::super::shader_cache::CompiledShader;
use super::options::{BlendMode, KernelMode, PaintOptions};

pub(super) const SHADER_PATH_DIFFUSE: &str = "shaders/map_drawing.glsl";
pub(super) const SHADER_PATH_VOID: &str = "shaders/void_drawing.glsl";
pub(super) const SHADER_PATH_FILTER: &str = "shaders/map_blur_drawing.glsl";
pub(super) const SHADER_PATH_HEIGHT: &str = "shaders/map_height_drawing.glsl";
pub(super) const SHADER_PATH_DNTS: &str = "shaders/dnts_drawing.glsl";

pub(super) const HEIGHTMAP_ENGINE_NAME: &str = "$heightmap";

pub(super) fn set_region_uniforms(
    interface: &NativeInterfaceRef,
    shader: &CompiledShader,
    m_coord: &[f32; 8],
) {
    let gfx = interface.gfx();
    let u = &shader.uniforms;
    if u.x1 >= 0 {
        let _ = gfx.uniform(u.x1, [m_coord[0], 0.0, 0.0, 0.0], 1);
    }
    if u.x2 >= 0 {
        let _ = gfx.uniform(u.x2, [m_coord[4], 0.0, 0.0, 0.0], 1);
    }
    if u.z1 >= 0 {
        let _ = gfx.uniform(u.z1, [m_coord[1], 0.0, 0.0, 0.0], 1);
    }
    if u.z2 >= 0 {
        let _ = gfx.uniform(u.z2, [m_coord[3], 0.0, 0.0, 0.0], 1);
    }
}

pub(super) fn set_diffuse_uniforms(
    interface: &NativeInterfaceRef,
    shader: &CompiledShader,
    opts: &PaintOptions,
) {
    let gfx = interface.gfx();
    let u = &shader.uniforms;
    if u.strength >= 0 {
        let _ = gfx.uniform(u.strength, [opts.strength, 0.0, 0.0, 0.0], 1);
    }
    if u.falloff_factor >= 0 {
        let _ = gfx.uniform(u.falloff_factor, [opts.falloff_factor, 0.0, 0.0, 0.0], 1);
    }
    if u.feature_factor >= 0 {
        let _ = gfx.uniform(u.feature_factor, [opts.feature_factor, 0.0, 0.0, 0.0], 1);
    }
    if u.diffuse_color >= 0 {
        let mut c = opts.diffuse_color;
        c[3] = 1.0;
        let _ = gfx.uniform(u.diffuse_color, c, 4);
    }
    if u.pattern_rotation >= 0 {
        let _ = gfx.uniform(u.pattern_rotation, [opts.pattern_rotation, 0.0, 0.0, 0.0], 1);
    }
}

pub(super) fn map_size(interface: &NativeInterfaceRef) -> Option<(i32, i32)> {
    let (mmx, mmz) = interface.metal_map().get_metal_map_size().ok()?;
    Some((mmx * 16, mmz * 16))
}

/// GLSL expression substituted into `map_drawing.glsl` for the selected blend
/// mode.
pub(super) fn blend_mode_expr(mode: BlendMode) -> &'static str {
    match mode {
        BlendMode::Normal => "mix(color,mapColor,color.a);",
        BlendMode::Add => "mix((mapColor+color),mapColor,color.a);",
        BlendMode::ColorBurn => "mix(1.0-(1.0-mapColor)/color,mapColor,color.a);",
        BlendMode::ColorDodge => "mix(mapColor/(1.0-color),mapColor,color.a);",
        BlendMode::Color => "mix(sqrt(dot(mapColor.rgb,mapColor.rgb)) * normalize(color),mapColor,color.a);",
        BlendMode::Darken => "mix(min(mapColor,color),mapColor,color.a);",
        BlendMode::Difference => "mix(abs(color-mapColor),mapColor,color.a);",
        BlendMode::Exclusion => "mix(color+mapColor-(2.0*color*mapColor),mapColor,color.a);",
        BlendMode::HardLight => "mix(mix(2.0 * mapColor * color,1.0 - 2.0*(1.0-color)*(1.0-mapColor),min(1.0,max(0.0,10.0*(dot(vec4(0.25,0.65,0.1,0.0),color)- 0.45)))),mapColor,color.a);",
        BlendMode::InverseDifference => "mix(1.0-abs(mapColor-color),mapColor,color.a);",
        BlendMode::Lighten => "mix(max(color,mapColor),mapColor,color.a);",
        BlendMode::Luminance => "mix(dot(color,vec4(0.25,0.65,0.1,0.0))*normalize(mapColor),mapColor,color.a);",
        BlendMode::Multiply => "mix(color*mapColor,mapColor,color.a);",
        BlendMode::Overlay => "mix(mix(2.0 * mapColor * color,1.0 - 2.0*(1.0-color)*(1.0-mapColor),min(1.0,max(0.0,10.0*(dot(vec4(0.25,0.65,0.1,0.0),mapColor)- 0.45)))),mapColor,color.a);",
        BlendMode::Premultiplied => "vec4(color.rgb + (1.0-color.a)*mapColor.rgb, (color.a+mapColor.a));",
        BlendMode::Screen => "mix(1.0-(1.0-mapColor)*(1.0-color),mapColor,color.a);",
        BlendMode::SoftLight => "mix(2.0*mapColor*color+mapColor*mapColor-2.0*mapColor*mapColor*color,mapColor,color.a);",
        BlendMode::Subtract => "mix(mapColor-color,mapColor,color.a);",
    }
}

pub(super) fn kernel_for(mode: KernelMode) -> [f32; 9] {
    match mode {
        KernelMode::Blur => [
            0.0625, 0.125, 0.0625, 0.125, 0.25, 0.125, 0.0625, 0.125, 0.0625,
        ],
        KernelMode::BottomSobel => [-1.0, -2.0, -1.0, 0.0, 0.0, 0.0, 1.0, 2.0, 1.0],
        KernelMode::Emboss => [-2.0, -1.0, 0.0, -1.0, 1.0, 1.0, 0.0, 1.0, 2.0],
        KernelMode::LeftSobel => [1.0, 0.0, -1.0, 2.0, 0.0, -2.0, 1.0, 0.0, -1.0],
        KernelMode::Outline => [-1.0, -1.0, -1.0, -1.0, 8.0, -1.0, -1.0, -1.0, -1.0],
        KernelMode::RightSobel => [-1.0, 0.0, 1.0, -2.0, 0.0, 2.0, -1.0, 0.0, 1.0],
        KernelMode::Sharpen => [0.0, -1.0, 0.0, -1.0, 5.0, -1.0, 0.0, -1.0, 0.0],
        KernelMode::TopSobel => [1.0, 2.0, 1.0, 0.0, 0.0, 0.0, -1.0, -2.0, -1.0],
    }
}
