//! Per-mode shader compilation + cache for the paint passes. Each compiled
//! variant is keyed by `(shader_path, blend_mode)`; blend mode is only used by
//! the pen shader's `%s` template, other shaders ignore it.

use spring_native::prelude::NativeInterfaceRef;

/// Uniform-location set used by the pen / void / filter / height / dnts shaders.
/// Any field that doesn't exist in a given shader stays at `-1`.
#[derive(Default, Clone)]
pub struct PaintUniforms {
    pub x1: i32,
    pub x2: i32,
    pub z1: i32,
    pub z2: i32,
    pub pattern_rotation: i32,
    pub strength: i32,
    pub falloff_factor: i32,
    pub feature_factor: i32,
    pub diffuse_color: i32,
    pub void_factor: i32,
    pub kernel: i32,
    pub min_height: i32,
    pub max_height: i32,
    pub color_index: i32,
    pub exclusive: i32,
    pub value: i32,
    pub map_tex: i32,
    pub pattern_texture: i32,
    pub brush_texture: i32,
    pub height_texture: i32,
}

#[derive(Clone)]
pub struct CompiledShader {
    pub shader: u32,
    pub uniforms: PaintUniforms,
}

struct CachedShader {
    path: String,
    mode: String,
    compiled: CompiledShader,
}

#[derive(Default)]
pub struct ShaderCache {
    entries: Vec<CachedShader>,
}

impl ShaderCache {
    pub fn new() -> Self {
        Self::default()
    }

    /// Get (or compile + cache) a shader for `path`. `mode` is substituted into
    /// any `%s` in the source; used by the pen shader to inject a blend-mode
    /// expression. Other shader files have no `%s` and ignore `mode`.
    pub fn get_or_compile(
        &mut self,
        interface: &NativeInterfaceRef,
        path: &str,
        mode: &str,
    ) -> Option<CompiledShader> {
        if let Some(hit) = self
            .entries
            .iter()
            .find(|c| c.path == path && c.mode == mode)
        {
            return Some(hit.compiled.clone());
        }

        let src = read_shader_source(interface, path)?;
        let frag = if src.contains("%s") {
            src.replacen("%s", mode, 1)
        } else {
            src
        };
        let frag = normalize_paint_shader_mix(frag);

        let gfx = interface.gfx();
        let (shader, _log) =
            match gfx.create_shader(
                "",
                "",
                "",
                "",
                "",
                &frag,
                "",
                spring_native::GfxCreateShaderOptions::default(),
            ) {
                Ok(s) => s,
                Err(err) => {
                    log::error!("shader_cache: create_shader({path}) failed: {err:?}");
                    return None;
                }
            };
        if shader == 0 {
            let log = gfx.get_shader_log().ok().flatten().unwrap_or_default();
            log::error!("shader_cache: {path} compile failed: {log}");
            return None;
        }

        let uniforms = collect_uniforms(interface, shader);
        bind_sampler_units(interface, shader, &uniforms);
        let compiled = CompiledShader { shader, uniforms };
        self.entries.push(CachedShader {
            path: path.to_string(),
            mode: mode.to_string(),
            compiled: compiled.clone(),
        });
        Some(compiled)
    }
}

fn normalize_paint_shader_mix(src: String) -> String {
    if !src.contains("vec4 mix(vec4 penColor, vec4 mapColor, float alpha)") {
        return src;
    }
    src.replace(
        "vec4 mix(vec4 penColor, vec4 mapColor, float alpha)",
        "vec4 paintMix(vec4 penColor, vec4 mapColor, float alpha)",
    )
    .replace("mix(", "paintMix(")
}

/// Bind each sampler2D uniform to a fixed texture unit. GLSL defaults all
/// samplers to unit 0, so without this the pattern + brush textures would
/// sample whatever's bound to unit 0 (the live tile).
fn bind_sampler_units(interface: &NativeInterfaceRef, shader: u32, u: &PaintUniforms) {
    let gfx = interface.gfx();
    let _ = gfx.use_shader(shader);
    if u.map_tex >= 0 {
        let _ = gfx.uniform_int(u.map_tex, [0, 0, 0, 0], 1);
    }
    if u.pattern_texture >= 0 {
        let _ = gfx.uniform_int(u.pattern_texture, [1, 0, 0, 0], 1);
    }
    if u.brush_texture >= 0 {
        let _ = gfx.uniform_int(u.brush_texture, [2, 0, 0, 0], 1);
    }
    if u.height_texture >= 0 {
        let _ = gfx.uniform_int(u.height_texture, [2, 0, 0, 0], 1);
    }
    let _ = gfx.use_shader(0);
}

fn read_shader_source(interface: &NativeInterfaceRef, path: &str) -> Option<String> {
    match interface.vfs().read_file_as_string(path) {
        Ok(Some(s)) => Some(s),
        Ok(None) => {
            log::error!("shader_cache: shader source not found: {path}");
            None
        }
        Err(err) => {
            log::error!("shader_cache: vfs read({path}) failed: {err:?}");
            None
        }
    }
}

fn collect_uniforms(interface: &NativeInterfaceRef, shader: u32) -> PaintUniforms {
    let gfx = interface.gfx();
    let loc = |name: &str| gfx.get_uniform_location(shader, name).unwrap_or(-1);
    PaintUniforms {
        x1: loc("x1"),
        x2: loc("x2"),
        z1: loc("z1"),
        z2: loc("z2"),
        pattern_rotation: loc("patternRotation"),
        strength: loc("strength"),
        falloff_factor: loc("falloffFactor"),
        feature_factor: loc("featureFactor"),
        diffuse_color: loc("diffuseColor"),
        void_factor: loc("voidFactor"),
        kernel: loc("kernel"),
        min_height: loc("minHeight"),
        max_height: loc("maxHeight"),
        color_index: loc("colorIndex"),
        exclusive: loc("exclusive"),
        value: loc("value"),
        map_tex: loc("mapTex"),
        pattern_texture: loc("patternTexture"),
        brush_texture: loc("brushTexture"),
        height_texture: loc("heightTexture"),
    }
}
