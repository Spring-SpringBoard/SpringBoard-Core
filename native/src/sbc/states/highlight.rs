//! Ground overlays drawn in `draw_world`: the selection marker under features
//! and areas, and the cursor overlays the editing states draw (a placement
//! ghost, a brush outline).
//!
//! Units already glow through the engine's own selection; features and areas
//! have none, so a ring is drawn here, as the Lua editor draws its own
//! indicator.

use spring_native::prelude::NativeInterfaceRef;

use crate::sbc::objects::ObjectKind;
use crate::sbc::render::ModelShader;

const GL_LINE_LOOP: u32 = 0x0002;
const GL_LINES: u32 = 0x0001;
const GL_QUADS: u32 = 0x0007;
const GL_MODELVIEW: u32 = 0x1700;
const GL_LEQUAL: u32 = 0x0203;
const GL_SRC_ALPHA: u32 = 0x0302;
const GL_ONE_MINUS_SRC_ALPHA: u32 = 0x0303;
const GL_ONE: u32 = 1;
const SEGMENTS: usize = 32;

/// Outline each selected feature with a box the size of the object, as
/// `FeatureBridge.DrawSelected` does. Called from `draw_world_pre_unit`, so the
/// box lands under the model rather than over it.
///
/// Each entry is the object's centre and its radius.
pub(crate) fn draw_selected_features(
    interface: &NativeInterfaceRef,
    boxes: &[(f32, f32, f32, f32)],
) {
    if boxes.is_empty() {
        return;
    }
    let gfx = interface.gfx();
    let _ = gfx.depth_test(false, false, 0);
    let _ = gfx.line_width(2.0);
    let _ = gfx.color(0.0, 1.0, 0.0, 1.0);

    for &(cx, cy, cz, radius) in boxes {
        // Lua never draws a box smaller than 20 across, so a tiny feature is
        // still visible.
        let half = radius.max(10.0);
        let _ = gfx.begin_end(GL_LINE_LOOP, || {
            for (dx, dz) in [(-half, -half), (half, -half), (half, half), (-half, half)] {
                let _ = gfx.vertex(cx + dx, cy, cz + dz, 1.0, 3);
            }
        });
    }

    reset(interface);
}

/// Draws the brush pattern under the cursor, as `AbstractMapEditingState:DrawShape`
/// does: the pattern is bound as a texture on a single rotated ground rectangle
/// and a shader takes its alpha, so the preview is the filtered image rather than
/// a mesh of sampled cells.
pub(crate) struct BrushPreview {
    shader: Option<u32>,
}

/// Only the pattern's alpha is used; its colour is the brush tint.
const BRUSH_FRAGMENT: &str = "
uniform sampler2D brushTex;
void main()
{
    vec4 brushColor = texture2D(brushTex, gl_TexCoord[0].st);
    gl_FragColor = gl_Color * brushColor.a;
}
";

impl BrushPreview {
    pub(crate) fn new() -> Self {
        BrushPreview { shader: None }
    }

    /// `pattern` is a VFS path, which the engine resolves as a texture.
    pub(crate) fn draw(
        &mut self,
        interface: &NativeInterfaceRef,
        pattern: &str,
        cx: f32,
        cz: f32,
        size: f32,
        rotation_degrees: f32,
    ) -> bool {
        let Some(shader) = self.shader(interface) else {
            return false;
        };
        let gfx = interface.gfx();
        if !gfx.bind_texture(pattern, 0, true).unwrap_or(false) {
            return false;
        }

        let _ = gfx.use_shader(shader);
        let _ = gfx.blending(true);
        // Lua's "alpha_add": the brush glows over the terrain instead of hiding it.
        let _ = gfx.blend_func(GL_SRC_ALPHA, GL_ONE);
        let _ = gfx.color(0.0, 1.0, 1.0, 0.5);
        let _ = gfx.depth_mask(false);
        let _ = gfx.depth_test(false, false, 0);
        let _ = gfx.culling(false);

        let half = size * 0.5;
        let y = interface.terrain().get_ground_height(cx, cz).unwrap_or(0.0) - 1.0;
        let _ = gfx.matrix_mode(GL_MODELVIEW);
        let _ = gfx.push_matrix();
        // Rotate about the rect's centre, then draw the unit quad in its corner.
        let _ = gfx.translate(cx, y, cz);
        let _ = gfx.rotate(rotation_degrees, 0.0, 1.0, 0.0);
        let _ = gfx.translate(-half, 0.0, -half);
        let _ = gfx.scale(size, 1.0, size);
        let _ = gfx.begin_end(GL_QUADS, || {
            for (u, v) in [(0.0, 0.0), (1.0, 0.0), (1.0, 1.0), (0.0, 1.0)] {
                let _ = gfx.tex_coord(u, v, 0.0, 0.0, 2);
                let _ = gfx.vertex(u, 0.0, v, 1.0, 3);
            }
        });
        let _ = gfx.pop_matrix();

        let _ = gfx.use_shader(0);
        let _ = gfx.bind_texture(pattern, 0, false);
        let _ = gfx.blend_func(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
        let _ = gfx.depth_mask(true);
        reset(interface);
        true
    }

    /// Compiled on first draw: there is no GL context to compile against until
    /// the first frame is drawn.
    fn shader(&mut self, interface: &NativeInterfaceRef) -> Option<u32> {
        if self.shader.is_none() {
            let gfx = interface.gfx();
            let (id, _) = gfx
                .create_shader(
                    "",
                    "",
                    "",
                    "",
                    "",
                    BRUSH_FRAGMENT,
                    "",
                    false,
                    0,
                    false,
                    0,
                    false,
                    0,
                )
                .ok()?;
            if id == 0 {
                if let Ok(Some(log)) = gfx.get_shader_log() {
                    log::warn!("brush preview shader failed to compile: {log}");
                }
                return None;
            }
            if let Ok(location) = gfx.get_uniform_location(id, "brushTex") {
                let _ = gfx.use_shader(id);
                let _ = gfx.uniform_int(location, [0, 0, 0, 0], 1);
                let _ = gfx.use_shader(0);
            }
            self.shader = Some(id);
        }
        self.shader
    }
}

/// Draw a cursor ring at a ground position, optionally with a facing spoke. Used
/// by the editing states to preview where a click lands (the placement ghost)
/// and the reach of a brush.
pub(crate) fn draw_cursor_ring(
    interface: &NativeInterfaceRef,
    cx: f32,
    cz: f32,
    radius: f32,
    facing: Option<f32>,
    rgba: (f32, f32, f32, f32),
) {
    let gfx = interface.gfx();
    let _ = gfx.depth_test(true, false, GL_LEQUAL);
    let _ = gfx.line_width(2.0);
    let _ = gfx.color(rgba.0, rgba.1, rgba.2, rgba.3);

    ring(interface, cx, cz, radius);
    if let Some(yaw) = facing {
        spoke(interface, cx, cz, radius, yaw);
    }

    reset(interface);
}

/// One object about to be placed: what it is, and where it would land.
pub(crate) struct ObjectGhost {
    pub kind: ObjectKind,
    pub def_id: i32,
    pub team_id: i32,
    pub x: f32,
    pub y: f32,
    pub z: f32,
    pub yaw: f32,
}

/// Draw the model currently armed for placement. Mirrors Lua's `DrawObject`:
/// push a world transform, tint, and render the def shape under the model
/// shader -- which is what textures it. Without the shader an S3O model draws as
/// a flat white silhouette.
pub(crate) fn draw_object_ghost(
    interface: &NativeInterfaceRef,
    shader: &mut ModelShader,
    ghost: &ObjectGhost,
) {
    let &ObjectGhost {
        kind,
        def_id,
        team_id,
        x,
        y,
        z,
        yaw,
    } = ghost;

    let gfx = interface.gfx();
    let _ = gfx.depth_test(true, true, GL_LEQUAL);
    let _ = gfx.depth_mask(true);
    let _ = gfx.blending(true);
    let _ = gfx.matrix_mode(GL_MODELVIEW);
    let _ = gfx.push_matrix();
    let _ = gfx.translate(x, y, z);
    let _ = gfx.rotate(yaw.to_degrees(), 0.0, 1.0, 0.0);

    // Lua's ghost tint: the model shows through, greened and translucent.
    let tint = [0.4, 1.0, 0.4, 0.8];
    let shaded = shader.bind(interface, tint);
    let _ = gfx.color(tint[0], tint[1], tint[2], tint[3]);

    match kind {
        ObjectKind::Unit => {
            let _ = gfx.unit_shape_textures(def_id, true);
            let _ = gfx.unit_shape(def_id, team_id, true, false, true);
            let _ = gfx.unit_shape_textures(def_id, false);
        }
        ObjectKind::Feature => {
            let _ = gfx.feature_shape_textures(def_id, true);
            let _ = gfx.feature_shape(def_id, team_id, true, false, true);
            let _ = gfx.feature_shape_textures(def_id, false);
        }
        ObjectKind::Area => {}
    }

    if shaded {
        shader.unbind(interface);
    }
    let _ = gfx.pop_matrix();
    reset(interface);
}

/// One ground-hugging ring, traced at the terrain height so it follows slopes.
fn ring(interface: &NativeInterfaceRef, cx: f32, cz: f32, radius: f32) {
    let gfx = interface.gfx();
    let terrain = interface.terrain();
    let _ = gfx.begin_end(GL_LINE_LOOP, || {
        for i in 0..SEGMENTS {
            let a = i as f32 / SEGMENTS as f32 * std::f32::consts::TAU;
            let x = cx + radius * a.cos();
            let z = cz + radius * a.sin();
            let y = terrain.get_ground_height(x, z).unwrap_or(0.0) + 2.0;
            let _ = gfx.vertex(x, y, z, 1.0, 3);
        }
    });
}

/// A line from the centre outward along `yaw`, marking the placed object's facing.
fn spoke(interface: &NativeInterfaceRef, cx: f32, cz: f32, radius: f32, yaw: f32) {
    let gfx = interface.gfx();
    let terrain = interface.terrain();
    let (ex, ez) = (cx + radius * yaw.sin(), cz + radius * yaw.cos());
    let _ = gfx.begin_end(GL_LINES, || {
        let cy = terrain.get_ground_height(cx, cz).unwrap_or(0.0) + 2.0;
        let ey = terrain.get_ground_height(ex, ez).unwrap_or(0.0) + 2.0;
        let _ = gfx.vertex(cx, cy, cz, 1.0, 3);
        let _ = gfx.vertex(ex, ey, ez, 1.0, 3);
    });
}

fn reset(interface: &NativeInterfaceRef) {
    let gfx = interface.gfx();
    let _ = gfx.color(1.0, 1.0, 1.0, 1.0);
    let _ = gfx.line_width(1.0);
    let _ = gfx.depth_test(true, false, 0);
}
