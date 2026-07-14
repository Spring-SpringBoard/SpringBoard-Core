//! Brush states over the map, a port of `abstract_map_editing_state.lua` and
//! `abstract_heightmap_editing_state.lua`.
//!
//! Press paints once and opens a streaming group; holding keeps painting from
//! `update`; release closes the group, so a whole stroke is one undo entry.

use std::collections::HashSet;
use std::time::Instant;

use spring_native::prelude::NativeInterfaceRef;

use crate::sbc::command_system::command::Command;
use crate::sbc::heightmap::commands::set_heightmap_brush_command::SetHeightmapBrushCommand;
use crate::sbc::states::brush_settings::BrushSettings;
use crate::sbc::states::highlight::BrushPreview;
use crate::sbc::states::shapes::{brush_opts, load_shape};
use crate::sbc::states::state::{cursor, trace_ground, EditorState, StateContext};

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
    preview: BrushPreview,
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
            preview: BrushPreview::new(),
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
        ctx.command(Box::new(SetHeightmapBrushCommand::new(brush_opts(
            pattern, &shape,
        ))));
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

    /// Validate everything a stroke needs before opening a grouped command.
    /// This prevents empty undo entries when no pattern/material is selected or
    /// when the selected heightmap pattern cannot be decoded.
    fn prepare_paint(&mut self, ctx: &mut StateContext) -> bool {
        let Some(pattern) = self.brush.pattern_texture.clone() else {
            log::warn!("{} brush cannot paint: no pattern selected", self.name());
            return false;
        };
        if self.kind == BrushKind::Texture {
            let ready =
                self.brush.texture_paint_mode != "paint" || !self.brush.brush_textures.is_empty();
            if !ready {
                log::warn!("texture brush cannot paint: no saved material selected");
            }
            return ready;
        }
        self.ensure_shape(ctx, &pattern)
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
        let command: Box<dyn Command> = match self.kind {
            BrushKind::ShapeModify => {
                use crate::sbc::heightmap::commands::terrain_shape_modify_command::{
                    Opts, TerrainShapeModifyCommand,
                };
                Box::new(TerrainShapeModifyCommand::new(Opts {
                    rotation,
                    x: cx,
                    z: cz,
                    shape_name: pattern,
                    strength: self.signed_strength(button),
                    size,
                }))
            }
            BrushKind::Smooth => {
                use crate::sbc::heightmap::commands::terrain_smooth_command::{
                    Opts, TerrainSmoothCommand,
                };
                let strength = self.signed_strength(button).abs();
                // Lua's sigma curve, clamped the same way.
                let sigma = (strength.sqrt().sqrt() / 2.0).clamp(0.20, 1.5);
                Box::new(TerrainSmoothCommand::new(Opts {
                    rotation,
                    x: cx,
                    z: cz,
                    shape_name: pattern,
                    strength,
                    size,
                    sigma,
                }))
            }
            BrushKind::Level => {
                use crate::sbc::heightmap::commands::terrain_level_command::{
                    Opts, TerrainLevelCommand,
                };
                Box::new(TerrainLevelCommand::new(Opts {
                    rotation,
                    x: cx,
                    z: cz,
                    shape_name: pattern,
                    strength: self.signed_strength(button),
                    size,
                    height: self.brush.height,
                    apply_dir_id: self.brush.apply_dir.id(),
                }))
            }
            BrushKind::Metal => {
                use crate::sbc::metal::commands::terrain_metal_command::{
                    Opts, TerrainMetalCommand,
                };
                // Right-click erases: Lua multiplies the amount by 0.
                Box::new(TerrainMetalCommand::new(Opts {
                    rotation,
                    x: cx,
                    z: cz,
                    shape_name: pattern,
                    amount: if button == RIGHT {
                        0.0
                    } else {
                        self.brush.amount
                    },
                    size,
                }))
            }
            BrushKind::Grass => {
                use crate::sbc::grass::commands::terrain_grass_command::{
                    Opts, TerrainGrassCommand,
                };
                Box::new(TerrainGrassCommand::new(Opts {
                    rotation,
                    x: cx,
                    z: cz,
                    shape_name: pattern,
                    amount: if button == RIGHT { 0.0 } else { 1.0 },
                    size,
                }))
            }
            // The texture brush takes the *corner*, not the centre, and its
            // rotations are radians. `brushTexture` is a material map of
            // channel -> texture.
            BrushKind::Texture => {
                if self.brush.texture_paint_mode == "paint" && self.brush.brush_textures.is_empty()
                {
                    return;
                }
                use crate::sbc::textures::commands::terrain_change_texture_command::{
                    Opts, TerrainChangeTextureCommand,
                };
                let enabled = &self.brush.texture_enabled;
                let action = if button == RIGHT { -1.0 } else { 1.0 };
                Box::new(TerrainChangeTextureCommand::new(Opts {
                    x: x - size / 2.0,
                    z: z - size / 2.0,
                    size,
                    paint_mode: self.brush.texture_paint_mode.clone(),
                    pattern_texture: pattern.into(),
                    pattern_rotation: rotation.to_radians(),
                    brush_texture: serde_json::to_value(&self.brush.brush_textures)
                        .unwrap_or_default(),
                    extra: serde_json::json!({
                        "diffuseEnabled": enabled.get("diffuse").copied().unwrap_or(false),
                        "specularEnabled": enabled.get("specular").copied().unwrap_or(false),
                        "emissionEnabled": enabled.get("emission").copied().unwrap_or(false),
                        "reflEnabled": enabled.get("refl").copied().unwrap_or(false),
                    }),
                    mode: self.brush.mode.clone(),
                    kernel_mode: self.brush.kernel_mode.clone(),
                    tex_scale: self.brush.tex_scale,
                    // The command takes the material's own rotation in radians.
                    rotation: self.brush.tex_rotation.to_radians(),
                    tex_offset_x: self.brush.tex_offset_x,
                    tex_offset_y: self.brush.tex_offset_y,
                    diffuse_color: self.brush.diffuse_color,
                    falloff_factor: self.brush.falloff_factor,
                    feature_factor: self.brush.feature_factor,
                    strength: self.brush.strength,
                    value: self.brush.value,
                    void_factor: self.brush.void_factor * action,
                    color_index: (self.brush.color_index as f32 * action) as i32,
                    exclusive: if self.brush.exclusive { 1 } else { 0 },
                    ..Default::default()
                }))
            }
        };
        ctx.command(command);
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
            log::warn!(
                "{} brush cannot paint: cursor did not hit the ground",
                self.name()
            );
            return true;
        };
        if !self.prepare_paint(ctx) {
            return true;
        }
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
        let Some(mouse) = cursor(ctx.interface) else {
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
        // Raising ground far enough can put the surface above the camera, and the
        // ray then starts inside it: the stroke simply stops painting until the
        // cursor is over ground again.
        let Some(hit) = trace_ground(ctx.interface, mouse.x, mouse.y) else {
            return;
        };
        self.last = Some((hit.x, hit.z));
        self.apply(ctx, hit.x, hit.z, button);
    }

    /// Show the brush's actual alpha footprint on the ground under the cursor.
    fn draw_world(&mut self, interface: &NativeInterfaceRef) {
        let Some(pattern) = self.brush.pattern_texture.clone() else {
            return;
        };
        // Texture Paint is not armed until a saved material has been chosen.
        if self.kind == BrushKind::Texture && self.brush.brush_textures.is_empty() {
            return;
        }
        let Some(mouse) = cursor(interface) else {
            return;
        };
        let Some(hit) = trace_ground(interface, mouse.x, mouse.y) else {
            return;
        };
        let size = self.brush.size;
        // Lua draws only the selected pattern. If its texture or shader cannot
        // be used, draw nothing rather than inventing a misleading brush.
        let _ = self
            .preview
            .draw(interface, &pattern, hit.x, hit.z, size, self.brush.rotation);
    }
}
