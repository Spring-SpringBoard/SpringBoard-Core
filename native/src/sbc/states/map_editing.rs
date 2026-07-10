//! Brush states over the map, a port of `abstract_map_editing_state.lua` and
//! `abstract_heightmap_editing_state.lua`.
//!
//! Press paints once and opens a streaming group; holding keeps painting from
//! `update`; release closes the group, so a whole stroke is one undo entry.

use std::collections::HashSet;
use std::time::Instant;

use crate::sbc::states::brush_settings::BrushSettings;
use crate::sbc::states::shapes::{load_shape, upload_payload};
use crate::sbc::states::state::{trace_ground, EditorState, StateContext};

const LEFT: i32 = 1;
const RIGHT: i32 = 3;

/// Which brush a `MapEditingState` is.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub(crate) enum BrushKind {
    /// Raise and lower the terrain.
    ShapeModify,
    Smooth,
    /// Level towards a target height.
    Level,
    Metal,
    Grass,
    Texture,
}

impl BrushKind {
    fn command(self) -> &'static str {
        match self {
            BrushKind::ShapeModify => "TerrainShapeModifyCommand",
            BrushKind::Smooth => "TerrainSmoothCommand",
            BrushKind::Level => "TerrainLevelCommand",
            BrushKind::Metal => "TerrainMetalCommand",
            BrushKind::Grass => "TerrainGrassCommand",
            BrushKind::Texture => "TerrainChangeTextureCommand",
        }
    }

    /// Lua's `initialDelay`: a beat before a held brush starts repeating, so a
    /// click is a single dab. The metal and grass brushes have none.
    fn initial_delay(self) -> f32 {
        match self {
            BrushKind::Metal | BrushKind::Grass => 0.0,
            _ => 0.3,
        }
    }
}

pub(crate) struct MapEditingState {
    kind: BrushKind,
    brush: BrushSettings,
    /// Patterns already uploaded as greyscale shapes this session.
    uploaded: HashSet<String>,
    painting: bool,
    /// Last position painted, so a jump does not smear the brush.
    last: Option<(f32, f32)>,
    last_apply: Option<Instant>,
    initial_delay_left: f32,
}

impl MapEditingState {
    pub(crate) fn new(kind: BrushKind, brush: BrushSettings) -> Self {
        MapEditingState {
            kind,
            brush,
            uploaded: HashSet::new(),
            painting: false,
            last: None,
            last_apply: None,
            initial_delay_left: kind.initial_delay(),
        }
    }

    /// The brush, so the manager can write wheel changes back to the model.
    pub(crate) fn brush(&self) -> &BrushSettings {
        &self.brush
    }

    pub(crate) fn set_brush(&mut self, brush: BrushSettings) {
        self.brush = brush;
    }

    /// Lua scales the repeat delay with the brush area: a huge brush is slow to
    /// apply, so it repeats less often.
    fn apply_delay(&self) -> f32 {
        let area = self.brush.size * self.brush.size / 5000.0 / 5000.0;
        area.max(0.01)
    }

    fn can_apply(&mut self) -> bool {
        let now = Instant::now();
        let Some(last) = self.last_apply else {
            self.last_apply = Some(now);
            return true;
        };
        let delay = self.apply_delay().max(self.initial_delay_left);
        if now.duration_since(last).as_secs_f32() >= delay {
            self.last_apply = Some(now);
            self.initial_delay_left = 0.0;
            return true;
        }
        false
    }

    /// Upload the pattern's greyscale shape once; the terrain commands refuse to
    /// run without it.
    fn ensure_shape(&mut self, ctx: &mut StateContext, pattern: &str) -> bool {
        if self.uploaded.contains(pattern) {
            return true;
        }
        let Some(shape) = load_shape(ctx.interface, pattern) else {
            log::warn!("brush pattern {pattern} could not be loaded");
            return false;
        };
        let payload = upload_payload(pattern, &shape);
        ctx.command_with("SetHeightmapBrushCommand", "greyscale", payload);
        self.uploaded.insert(pattern.to_string());
        true
    }

    fn start_painting(&mut self, ctx: &mut StateContext) {
        if self.painting {
            return;
        }
        self.initial_delay_left = self.kind.initial_delay();
        ctx.set_multiple_command_mode(true);
        self.painting = true;
    }

    fn stop_painting(&mut self, ctx: &mut StateContext) {
        if !self.painting {
            return;
        }
        ctx.set_multiple_command_mode(false);
        self.painting = false;
        self.last_apply = None;
    }

    /// One dab of the brush at world `(x, z)`.
    fn apply(&mut self, ctx: &mut StateContext, x: f32, z: f32, button: i32) {
        let Some(pattern) = self.brush.pattern_texture.clone() else {
            return;
        };
        // The heightmap-derived brushes sample a greyscale shape; the texture
        // brush binds the pattern as a GPU texture and needs no upload.
        if self.kind != BrushKind::Texture && !self.ensure_shape(ctx, &pattern) {
            return;
        }
        if !self.can_apply() {
            return;
        }

        let size = self.brush.size;
        // Lua passes the brush centre offset by half its size.
        let (cx, cz) = (x + size / 2.0, z + size / 2.0);
        let rotation = self.brush.rotation;

        // Right-click inverts a height brush, erases metal and grass.
        let opts = match self.kind {
            BrushKind::ShapeModify => {
                let strength = self.signed_strength(button);
                serde_json::json!({
                    "x": cx, "z": cz, "size": size, "rotation": rotation,
                    "shapeName": pattern, "strength": strength,
                })
            }
            BrushKind::Smooth => {
                let strength = self.signed_strength(button).abs();
                // Lua's sigma curve, clamped the same way.
                let sigma = (strength.sqrt().sqrt() / 2.0).clamp(0.20, 1.5);
                serde_json::json!({
                    "x": cx, "z": cz, "size": size, "rotation": rotation,
                    "shapeName": pattern, "strength": strength, "sigma": sigma,
                })
            }
            BrushKind::Level => serde_json::json!({
                "x": cx, "z": cz, "size": size, "rotation": rotation,
                "shapeName": pattern,
                "strength": self.signed_strength(button),
                "height": self.brush.height,
                "applyDirID": self.brush.apply_dir.id(),
            }),
            BrushKind::Metal => serde_json::json!({
                "x": cx, "z": cz, "size": size, "rotation": rotation,
                "shapeName": pattern,
                // Right-click erases: Lua multiplies the amount by 0.
                "amount": if button == RIGHT { 0.0 } else { self.brush.amount },
            }),
            BrushKind::Grass => serde_json::json!({
                "x": cx, "z": cz, "size": size, "rotation": rotation,
                "shapeName": pattern,
                "amount": if button == RIGHT { 0.0 } else { 1.0 },
            }),
            // The texture brush takes the *corner*, not the centre, and its
            // rotations are radians. `brushTexture` is a material: a map of
            // channel -> texture. Without a material model only the diffuse
            // channel is painted.
            BrushKind::Texture => {
                let Some(texture) = self.brush.brush_texture.clone() else {
                    return;
                };
                serde_json::json!({
                    "x": x - size / 2.0,
                    "z": z - size / 2.0,
                    "size": size,
                    "paintMode": "paint",
                    "patternTexture": pattern,
                    "patternRotation": rotation.to_radians(),
                    "brushTexture": { "diffuse": texture },
                    "mode": self.brush.mode,
                    "texScale": self.brush.tex_scale,
                    "strength": self.brush.strength,
                })
            }
        };
        ctx.command(self.kind.command(), opts);
    }

    fn signed_strength(&self, button: i32) -> f32 {
        if button == RIGHT {
            -self.brush.strength
        } else {
            self.brush.strength
        }
    }
}

impl EditorState for MapEditingState {
    fn name(&self) -> &'static str {
        match self.kind {
            BrushKind::ShapeModify => "terrain-shape-modify",
            BrushKind::Smooth => "terrain-smooth",
            BrushKind::Level => "terrain-level",
            BrushKind::Metal => "metal",
            BrushKind::Grass => "grass",
            BrushKind::Texture => "texture",
        }
    }

    fn leave(&mut self, ctx: &mut StateContext) {
        self.stop_painting(ctx);
    }

    fn mouse_press(&mut self, ctx: &mut StateContext, x: i32, y: i32, button: i32) -> bool {
        if button != LEFT && button != RIGHT {
            return false;
        }
        // Right-click on a level brush picks the target height off the ground,
        // rather than painting (Lua's TerrainSetState:MousePress).
        if self.kind == BrushKind::Level && button == RIGHT {
            if let Some(hit) = trace_ground(ctx.interface, x as f32, y as f32) {
                self.brush.set_height(hit.y);
            }
            return true;
        }
        let Some(hit) = trace_ground(ctx.interface, x as f32, y as f32) else {
            return true;
        };
        self.start_painting(ctx);
        self.last = Some((hit.x, hit.z));
        self.apply(ctx, hit.x, hit.z, button);
        true
    }

    fn mouse_release(&mut self, ctx: &mut StateContext, _x: i32, _y: i32, button: i32) -> bool {
        if button == LEFT || button == RIGHT {
            self.stop_painting(ctx);
        }
        false
    }

    fn mouse_wheel(&mut self, ctx: &mut StateContext, up: bool, _value: f32) -> bool {
        // Shift resizes, Alt rotates -- and nothing else consumes the wheel, so
        // the camera keeps zooming as usual.
        let Ok(mods) = ctx.interface.input().get_mod_key_state() else {
            return false;
        };
        const SHIFT: u32 = 1 << 0;
        const ALT: u32 = 1 << 2;
        if mods & SHIFT != 0 {
            self.brush.scale_size(up);
            return true;
        }
        if mods & ALT != 0 {
            self.brush.rotate(up);
            return true;
        }
        false
    }

    /// A held button keeps painting where the cursor is.
    fn update(&mut self, ctx: &mut StateContext) {
        if !self.painting {
            return;
        }
        let Ok(mouse) = ctx.interface.input().get_mouse_state() else {
            return;
        };
        let button = if mouse.left {
            LEFT
        } else if mouse.right {
            RIGHT
        } else {
            // The release callin can be missed if the cursor left the window.
            self.stop_painting(ctx);
            return;
        };
        let Some(hit) = trace_ground(ctx.interface, mouse.x, mouse.y) else {
            return;
        };
        self.last = Some((hit.x, hit.z));
        self.apply(ctx, hit.x, hit.z, button);
    }
}
