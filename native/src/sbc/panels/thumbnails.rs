//! Rendering unit/feature definitions to textures for the Objects grid.
//!
//! A native port of `object_defs_panel.lua`'s `PeriodicDraw`: each definition
//! gets a 128x128 FBO texture, into which its model is drawn (rotating) via the
//! native `gfx` API. The texture name (`!nativeN`) goes to the grid as a
//! `<texture src>`, which RmlUi resolves through `ParseTextureImage`'s
//! native-texture bridge.
//!
//! Texture creation and drawing must happen on the draw thread (they touch GL),
//! so this runs from `draw_screen`, not from the per-tick update.

use std::collections::BTreeMap;

use spring_native::prelude::{sys, NativeInterfaceRef};

use crate::sbc::panels::model_shader::ModelShader;

/// Matches the Lua icon size.
const SIZE: i32 = 128;

// GL enum values (the gfx API takes raw GLenums, as gl.* does in Lua).
const GL_TEXTURE_2D: u32 = 0x0DE1;
const GL_RGBA8: u32 = 0x8058;
const GL_LINEAR: u32 = 0x2601;
const GL_CLAMP_TO_EDGE: u32 = 0x812F;
const GL_LEQUAL: u32 = 0x0203;

#[derive(Clone, Copy, PartialEq, Eq)]
pub(crate) enum ThumbKind {
    Unit,
    Feature,
}

struct Thumb {
    def_id: i32,
    kind: ThumbKind,
    /// The `!nativeN` texture name once created on the draw thread.
    texture: Option<String>,
}

pub(crate) struct ThumbnailRenderer {
    /// Keyed by def name, matching the grid item id. Ordered, not a HashMap: the
    /// thumbnails are drawn in iteration order, and a HashMap's order is
    /// randomised per process, which made the defects below land on a different
    /// def every launch.
    thumbs: BTreeMap<String, Thumb>,
    team_id: i32,
    rotation: f32,
    /// A texture was created since the grid last read the names.
    names_dirty: bool,
    /// What actually textures the models.
    shader: ModelShader,
}

impl Default for ThumbnailRenderer {
    fn default() -> Self {
        ThumbnailRenderer {
            thumbs: BTreeMap::new(),
            team_id: 0,
            rotation: 0.0,
            names_dirty: false,
            shader: ModelShader::default(),
        }
    }
}

impl ThumbnailRenderer {
    /// Register a definition that needs a thumbnail. The texture is created
    /// later, on the draw thread.
    pub(crate) fn request(&mut self, def_name: &str, def_id: i32, kind: ThumbKind) {
        self.thumbs.entry(def_name.to_string()).or_insert(Thumb {
            def_id,
            kind,
            texture: None,
        });
    }

    pub(crate) fn set_team(&mut self, team_id: i32) {
        if self.team_id != team_id {
            self.team_id = team_id;
            // Re-tint on the next draw.
        }
    }

    /// The texture name for a def, if it has been created.
    pub(crate) fn texture_for(&self, def_name: &str) -> Option<&str> {
        self.thumbs.get(def_name)?.texture.as_deref()
    }

    /// Whether new texture names appeared since the last check.
    pub(crate) fn take_names_dirty(&mut self) -> bool {
        std::mem::take(&mut self.names_dirty)
    }

    /// Create any missing textures and redraw all thumbnails. Must run on the
    /// draw thread (from `draw_screen`).
    pub(crate) fn draw(&mut self, interface: &NativeInterfaceRef) {
        let gfx = interface.gfx();

        // Create missing textures first.
        for thumb in self.thumbs.values_mut() {
            if thumb.texture.is_some() {
                continue;
            }
            if let Ok(Some(name)) = gfx.create_texture(SIZE, SIZE, 0, fbo_params()) {
                thumb.texture = Some(name);
                self.names_dirty = true;
            }
        }

        // Slowly spin the models, as Lua does -- unless the harness asked for a
        // still image, since a spinning model can never match a golden.
        if !still_models() {
            self.rotation += 0.5;
        }

        // The state Lua's DrawIcons sets around the whole batch.
        let _ = gfx.push_matrix();
        let _ = gfx.depth_test(true, true, GL_LEQUAL);
        let _ = gfx.depth_mask(true);

        let team_id = self.team_id;
        let rotation = self.rotation;
        let team_color = team_color(interface, team_id);
        for thumb in self.thumbs.values() {
            let Some(texture) = thumb.texture.as_deref() else {
                continue;
            };
            let def_id = thumb.def_id;
            let kind = thumb.kind;
            // The background quad is textured, so the texture is bound outside
            // the render target, as Lua does.
            let _ = gfx.bind_texture(BACKGROUND, 0, true);
            let shader = &mut self.shader;
            let _ = gfx.render_to_texture(texture, || {
                draw_model(
                    interface, shader, def_id, kind, team_id, rotation, team_color,
                );
            });
        }

        let _ = gfx.blending(true);
        let _ = gfx.bind_texture("", 0, false);
        let _ = gfx.pop_matrix();
    }
}

/// Whether to hold the thumbnails still, for reproducible screenshots.
fn still_models() -> bool {
    static STILL: std::sync::OnceLock<bool> = std::sync::OnceLock::new();
    *STILL.get_or_init(|| std::env::var("SBC_STILL_MODELS").is_ok())
}

/// The team's colour, which the model shader tints the team-coloured texels with.
fn team_color(interface: &NativeInterfaceRef, team_id: i32) -> [f32; 4] {
    interface
        .display()
        .get_team_color(team_id)
        .map(|c| [c.r, c.g, c.b, c.a])
        .unwrap_or([1.0, 1.0, 1.0, 1.0])
}

/// What Lua scales by in RmlUi mode (`scale = scale * 1.5`).
const RMLUI_FIT: f32 = 1.5;

/// The VFS path of the background Lua draws behind each model.
const BACKGROUND: &str = "LuaUI/images/scenedit/background.png";

/// The radius the model is framed against, exactly as `GetObjectDefRadius` does
/// it: a unit uses its model radius, a feature the "magic" formula over its
/// model bounds. Never below 10.
fn def_radius(interface: &NativeInterfaceRef, def_id: i32, kind: ThumbKind) -> f32 {
    let radius = match kind {
        ThumbKind::Unit => {
            interface
                .utils()
                .get_unit_def_dimensions(def_id)
                .unwrap_or_default()
                .radius
        }
        ThumbKind::Feature => {
            let dims = interface
                .utils()
                .get_feature_def_dimensions(def_id)
                .unwrap_or_default();
            let dx = dims.maxx - dims.minx;
            let dy = dims.maxy - dims.miny;
            let dz = dims.maxz - dims.minz;
            dx.max(dy).max(dz) / 2.0 * std::f32::consts::SQRT_2 * 1.2
        }
    };
    radius.max(MIN_RADIUS)
}

const MIN_RADIUS: f32 = 10.0;

/// Draw one model into the bound render target. A straight port of Lua's
/// `ObjectDefsPanel:PeriodicDraw`, which is what renders these same models
/// correctly in the Chili and RmlUi UIs: the background quad, the model shader,
/// a fixed tilt, the running spin, and the model at its own scale. No projection
/// of our own, no depth clear, no alpha test -- none of that is in the original,
/// and the original is what works.
fn draw_model(
    interface: &NativeInterfaceRef,
    shader: &mut ModelShader,
    def_id: i32,
    kind: ThumbKind,
    team_id: i32,
    rotation: f32,
    team_color: [f32; 4],
) {
    let gfx = interface.gfx();

    // The background: a quad over the whole target, tinted. This is what fills
    // the cell -- there is no clear.
    let _ = gfx.color(0.2, 0.3, 0.3, 1.0);
    let _ = gfx.tex_rect(-1.0, -1.0, 1.0, 1.0, 0.0, 0.0, 1.0, 1.0);
    let _ = gfx.translate(0.0, 0.5, 0.0);

    // S3O models are textured *by* the engine's model shader; without it they
    // draw as flat white silhouettes.
    let shaded = shader.bind(interface, team_color);

    let scale = -RMLUI_FIT / def_radius(interface, def_id, kind);
    let _ = gfx.rotate(60.0, -1.0, 1.0, -0.5);
    let _ = gfx.rotate(rotation, 0.0, 1.0, 0.0);
    let _ = gfx.scale(scale, scale, scale);

    // rawState = true: the model draws through the fixed-function matrices set
    // here (as Lua's raw path does) rather than the in-world unit shader tied to
    // the game camera.
    match kind {
        ThumbKind::Unit => {
            let _ = gfx.unit_shape_textures(def_id, true);
            let _ = gfx.unit_shape(def_id, team_id, true, false, true);
            let _ = gfx.unit_shape_textures(def_id, false);
        }
        ThumbKind::Feature => {
            let _ = gfx.feature_shape_textures(def_id, true);
            let _ = gfx.feature_shape(def_id, team_id, true, false, true);
            let _ = gfx.feature_shape_textures(def_id, false);
        }
    }

    if shaded {
        shader.unbind(interface);
    }
}

/// A 128x128 RGBA FBO texture, exactly as Lua's `gl.CreateTexture` with
/// `fbo = true` makes it. No depth attachment -- Lua asks for none.
fn fbo_params() -> sys::GfxTextureParams {
    sys::GfxTextureParams {
        target: GL_TEXTURE_2D,
        format: GL_RGBA8,
        border: 0,
        minFilter: GL_LINEAR,
        magFilter: GL_LINEAR,
        wrapS: GL_CLAMP_TO_EDGE,
        wrapT: GL_CLAMP_TO_EDGE,
        wrapR: GL_CLAMP_TO_EDGE,
        compareFunc: 0,
        lodBias: 0.0,
        aniso: 0.0,
        samples: 0,
        fbo: true,
        fboDepth: false,
    }
}
