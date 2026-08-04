//! The engine's model shader, for drawing unit/feature models outside the world
//! render: the definition thumbnails and the placement ghost.
//!
//! A port of `scen_edit/view/model_shaders.lua`. S3O models are textured *by*
//! this shader -- drawn without it they come out as flat white silhouettes, with
//! no texture and no lighting. The engine ships the program in the VFS; it is
//! loaded and compiled here rather than reimplemented.

use spring_native::prelude::NativeInterfaceRef;

const VERTEX_PATH: &str = "shaders/ModelVertProg.glsl";
const FRAGMENT_PATH: &str = "shaders/ModelFragProg.glsl";

/// The fragment program has two hook points a caller may inject into. The
/// default shader wants neither, so they are substituted away -- leaving them in
/// place is a compile error.
const FRAGMENT_HOOKS: &[&str] = &["__FRAGMENT_GLOBAL_NAMESPACE__", "__FRAGMENT_POST_SHADING__"];

/// The texture units the model shader samples, by uniform name.
const SAMPLERS: &[(&str, i32)] = &[
    ("textureS3o1", 0),
    ("textureS3o2", 1),
    ("shadowTex", 2),
    ("specularTex", 3),
    ("reflectTex", 4),
    ("normalMap", 5),
];

const GL_SHADOW: u32 = 3;

/// The compiled model shader. Compiled on first use: there is no GL context to
/// compile against before the first frame.
#[derive(Default)]
pub(crate) struct ModelShader {
    shader: Option<u32>,
    team_color: i32,
    /// Compilation failed; do not retry every frame.
    failed: bool,
}

impl ModelShader {
    /// Bind the shader and set its uniforms for this frame. Returns false if it
    /// could not be compiled, in which case the caller should draw without it
    /// rather than draw nothing.
    pub(crate) fn bind(&mut self, interface: &NativeInterfaceRef, team_color: [f32; 4]) -> bool {
        let Some(shader) = self.ensure(interface) else {
            return false;
        };
        let gfx = interface.gfx();
        if !gfx.use_shader(shader).unwrap_or(false) {
            return false;
        }
        self.set_frame_uniforms(interface, shader);
        if self.team_color >= 0 {
            let _ = gfx.uniform(self.team_color, team_color, 4);
        }
        true
    }

    pub(crate) fn unbind(&self, interface: &NativeInterfaceRef) {
        let _ = interface.gfx().use_shader(0);
    }

    fn ensure(&mut self, interface: &NativeInterfaceRef) -> Option<u32> {
        if self.failed {
            return None;
        }
        if let Some(shader) = self.shader {
            return Some(shader);
        }

        let vfs = interface.vfs();
        let vertex = vfs.load_file(VERTEX_PATH, "").ok()?;
        let fragment = vfs.load_file(FRAGMENT_PATH, "").ok()?;
        let vertex = String::from_utf8_lossy(&vertex).into_owned();
        let mut fragment = String::from_utf8_lossy(&fragment).into_owned();
        for hook in FRAGMENT_HOOKS {
            fragment = fragment.replace(hook, "");
        }

        let gfx = interface.gfx();
        let (shader, _) = gfx
            .create_shader(
                "",
                &vertex,
                "",
                "",
                "",
                &fragment,
                "",
                spring_native::GfxCreateShaderOptions::default(),
            )
            .ok()?;
        if shader == 0 {
            if let Ok(Some(log)) = gfx.get_shader_log() {
                log::warn!("model shader failed to compile: {log}");
            }
            self.failed = true;
            return None;
        }

        // The samplers never change, so they are set once.
        let _ = gfx.use_shader(shader);
        for (name, unit) in SAMPLERS {
            if let Ok(location) = gfx.get_uniform_location(shader, name) {
                if location >= 0 {
                    let _ = gfx.uniform_int(location, [*unit, 0, 0, 0], 1);
                }
            }
        }
        let _ = gfx.use_shader(0);

        self.team_color = gfx.get_uniform_location(shader, "teamColor").unwrap_or(-1);
        self.shader = Some(shader);
        Some(shader)
    }

    /// The sun and shadow state, which the map's lighting changes.
    fn set_frame_uniforms(&self, interface: &NativeInterfaceRef, shader: u32) {
        let gfx = interface.gfx();
        let uniform = |name: &str, values: [f32; 4], count: u32| {
            if let Ok(location) = gfx.get_uniform_location(shader, name) {
                if location >= 0 {
                    let _ = gfx.uniform(location, values, count);
                }
            }
        };

        if let Ok((pos, ..)) = gfx.get_sun("pos", "") {
            uniform("sunDir", pos, 3);
        }
        if let Ok((ambient, ..)) = gfx.get_sun("ambient", "unit") {
            uniform("sunAmbient", ambient, 3);
        }
        if let Ok((diffuse, ..)) = gfx.get_sun("diffuse", "unit") {
            uniform("sunDiffuse", diffuse, 3);
        }
        if let Ok((density, ..)) = gfx.get_sun("shadowDensity", "unit") {
            uniform("shadowDensity", density, 1);
        }
        if let Ok(params) = gfx.get_shadow_map_params() {
            uniform("shadowParams", [params.x, params.y, params.z, params.w], 4);
        }
        if let Ok(pos) = interface.camera().get_camera_position() {
            uniform("cameraPos", [pos.x, pos.y, pos.z, 0.0], 3);
        }
        if let Ok(matrix) = gfx.get_matrix_data(GL_SHADOW) {
            if let Ok(location) = gfx.get_uniform_location(shader, "shadowMatrix") {
                if location >= 0 {
                    let _ = gfx.uniform_matrix(location, &matrix, false);
                }
            }
        }
    }
}
