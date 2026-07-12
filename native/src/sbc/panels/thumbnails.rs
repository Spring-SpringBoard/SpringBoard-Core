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

use std::collections::HashMap;

use spring_native::prelude::{sys, NativeInterfaceRef};

use crate::sbc::panels::model_shader::ModelShader;

/// Matches the Lua icon size.
const SIZE: i32 = 128;

// GL enum values (the gfx API takes raw GLenums, as gl.* does in Lua).
const GL_TEXTURE_2D: u32 = 0x0DE1;
const GL_RGBA8: u32 = 0x8058;
const GL_LINEAR: u32 = 0x2601;
const GL_CLAMP_TO_EDGE: u32 = 0x812F;
const GL_MODELVIEW: u32 = 0x1700;
const GL_PROJECTION: u32 = 0x1701;
const GL_LEQUAL: u32 = 0x0203;
const GL_COLOR_BUFFER_BIT: u32 = 0x0000_4000;
const GL_DEPTH_BUFFER_BIT: u32 = 0x0000_0100;

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
    /// Keyed by def name, matching the grid item id.
    thumbs: HashMap<String, Thumb>,
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
            thumbs: HashMap::new(),
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

        // Slowly spin the models, as Lua does.
        self.rotation += 0.7;

        let team_id = self.team_id;
        let rotation = self.rotation;
        // S3O models are textured by the engine's model shader; without it they
        // draw as flat white silhouettes.
        let team_color = team_color(interface, team_id);
        let shaded = self.shader.bind(interface, team_color);
        for thumb in self.thumbs.values() {
            let Some(texture) = thumb.texture.as_deref() else {
                continue;
            };
            let def_id = thumb.def_id;
            let kind = thumb.kind;
            let _ = gfx.render_to_texture(texture, || {
                draw_model(interface, def_id, kind, team_id, rotation);
            });
        }
        if shaded {
            self.shader.unbind(interface);
        }
    }
}

/// The team's colour, which the model shader tints the team-coloured texels with.
fn team_color(interface: &NativeInterfaceRef, team_id: i32) -> [f32; 4] {
    interface
        .display()
        .get_team_color(team_id)
        .map(|c| [c.r, c.g, c.b, c.a])
        .unwrap_or([1.0, 1.0, 1.0, 1.0])
}

/// How much of the cell the model fills, as Lua's `scale * 1.5` does. The model
/// is centred on its bounding box, so its half-extent maps to roughly this; a
/// little under 1.5 keeps a margin.
const RMLUI_FIT: f32 = 1.4;

fn def_dimensions(
    interface: &NativeInterfaceRef,
    def_id: i32,
    kind: ThumbKind,
) -> sys::UnitDefDimensions {
    let dims = match kind {
        ThumbKind::Unit => interface.utils().get_unit_def_dimensions(def_id),
        ThumbKind::Feature => interface.utils().get_feature_def_dimensions(def_id),
    };
    dims.unwrap_or_default()
}

/// The radius the model is framed against, as `ObjectDefsPanel:GetObjectDefRadius`
/// computes it: a unit uses its model radius, a feature its model bounds. Never
/// below 10, or a tiny model would be scaled up to fill the cell with noise.
fn def_radius(dims: &sys::UnitDefDimensions, kind: ThumbKind) -> f32 {
    let radius = match kind {
        ThumbKind::Unit => dims.radius,
        // Lua's "magic": half the largest extent, on the diagonal, with a margin.
        ThumbKind::Feature => {
            let dx = dims.maxx - dims.minx;
            let dy = dims.maxy - dims.miny;
            let dz = dims.maxz - dims.minz;
            dx.max(dy).max(dz) / 2.0 * std::f32::consts::SQRT_2 * 1.2
        }
    };
    radius.max(MIN_RADIUS)
}

const MIN_RADIUS: f32 = 10.0;

/// Draw one model into the bound FBO. Mirrors Lua's `PeriodicDraw`: a tinted
/// background quad, then the model under a fixed tilt plus the running spin.
fn draw_model(
    interface: &NativeInterfaceRef,
    def_id: i32,
    kind: ThumbKind,
    team_id: i32,
    rotation: f32,
) {
    let gfx = interface.gfx();
    // Two clears, as Lua does: the engine's Clear only sets the clear colour
    // when the bit is exactly COLOR_BUFFER_BIT, and only sets clear depth for a
    // lone DEPTH_BUFFER_BIT with count 1.
    let _ = gfx.clear(GL_COLOR_BUFFER_BIT, [0.2, 0.3, 0.3, 1.0], 4);
    let _ = gfx.clear(GL_DEPTH_BUFFER_BIT, [1.0, 0.0, 0.0, 0.0], 1);
    let _ = gfx.depth_test(true, true, GL_LEQUAL);
    let _ = gfx.depth_mask(true);
    // An identity projection only keeps z in [-1, 1], and a model tilted into
    // the view is far deeper than that -- it was being clipped away, leaving the
    // thin surviving sliver that looked like an off-centre model. Give the cell
    // a real depth range: x/y stay [-1, 1] (what the scale below is expressed
    // in), z spans [-DEPTH, DEPTH].
    const DEPTH: f32 = 100.0;
    #[rustfmt::skip]
    let ortho: [f32; 16] = [
        1.0, 0.0, 0.0,           0.0,
        0.0, 1.0, 0.0,           0.0,
        0.0, 0.0, -1.0 / DEPTH,  0.0,
        0.0, 0.0, 0.0,           1.0,
    ];
    let _ = gfx.matrix_mode(GL_PROJECTION);
    let _ = gfx.push_matrix();
    let _ = gfx.load_matrix(ortho);

    let _ = gfx.matrix_mode(GL_MODELVIEW);
    let _ = gfx.push_matrix();
    let _ = gfx.load_identity();

    // The model is scaled to *its own* radius, so a tree and a tank both fill
    // the cell; one fixed scale draws every model the same size, which overflows
    // the big ones. The negative sign flips it upright in this bottom-origin
    // projection.
    let dims = def_dimensions(interface, def_id, kind);
    let scale = -1.0 / def_radius(&dims, kind) * RMLUI_FIT;
    let _ = gfx.rotate(60.0, -1.0, 1.0, -0.5);
    let _ = gfx.rotate(rotation, 0.0, 1.0, 0.0);
    let _ = gfx.scale(scale, scale, scale);
    // A model's origin is not its centre -- for a tree it is the foot of the
    // trunk -- so drawing it at the origin puts it off to one side of the cell.
    // Centre it on the middle of its bounding box: `relMidPos` is the model's
    // *aim* point, which is not the same thing and does not centre it.
    let _ = gfx.translate(
        -(dims.minx + dims.maxx) * 0.5,
        -(dims.miny + dims.maxy) * 0.5,
        -(dims.minz + dims.maxz) * 0.5,
    );

    // rawState = true: the model draws through the fixed-function matrices set
    // here (as Lua's raw path does) rather than the in-world unit shader tied to
    // the game camera. What textures it is the model shader the caller bound.
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

    // Hand the UI back the matrices it was drawing with.
    let _ = gfx.pop_matrix();
    let _ = gfx.matrix_mode(GL_PROJECTION);
    let _ = gfx.pop_matrix();
    let _ = gfx.matrix_mode(GL_MODELVIEW);
    let _ = gfx.matrix_mode(GL_MODELVIEW);
}

/// A 128x128 RGBA FBO texture with a depth buffer, like Lua's `gl.CreateTexture`
/// with `fbo = true`.
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
        fboDepth: true,
    }
}
