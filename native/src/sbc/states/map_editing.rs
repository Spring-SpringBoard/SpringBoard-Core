//! Brush states over the map, a port of `abstract_map_editing_state.lua` and
//! `abstract_heightmap_editing_state.lua`.
//!
//! Press paints once and opens a streaming group; holding keeps painting from
//! `update`; release closes the group, so a whole stroke is one undo entry.

use std::collections::HashSet;
use std::time::Instant;

use spring_native::prelude::NativeInterfaceRef;

use crate::sbc::command_system::command::Command;
use crate::sbc::states::brush_settings::BrushSettings;
use crate::sbc::states::highlight::BrushPreview;
use crate::sbc::states::state::{cursor, trace_ground, EditorState, StateContext};

const LEFT: i32 = 1;
const RIGHT: i32 = 3;

/// A point in the common ground-trace coordinate system. Each domain decides
/// whether its command needs this point, or the centre/corner derived from it.
#[derive(Debug, Clone, Copy)]
pub(crate) struct BrushStamp {
    pub x: f32,
    pub z: f32,
    pub size: f32,
    pub rotation: f32,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub(crate) enum BrushButton {
    Primary,
    Secondary,
}

impl BrushButton {
    fn from_mouse(button: i32) -> Self {
        if button == RIGHT {
            Self::Secondary
        } else {
            Self::Primary
        }
    }

    pub(crate) fn is_secondary(self) -> bool {
        self == Self::Secondary
    }
}

/// Domain-owned behaviour for a map brush. Adding a tool means implementing
/// this trait next to its commands and referencing it from an action button;
/// the shared input/streaming state needs no new branch.
pub(crate) trait MapBrush: Sync {
    fn name(&self) -> &'static str;

    fn initial_delay(&self) -> f32 {
        0.3
    }

    /// Whether the current domain settings can produce a command.
    fn is_ready(&self, _brush: &BrushSettings) -> bool {
        true
    }

    /// Domain-specific setup before a stroke/dab. Heightmap tools upload their
    /// pattern here; texture tools need none.
    fn prepare(
        &self,
        _brush: &BrushSettings,
        _uploaded: &mut HashSet<String>,
        _ctx: &mut StateContext,
    ) -> bool {
        true
    }

    /// A tool may consume a press instead of painting. Terrain Set uses a
    /// secondary press to pick the target height.
    fn consume_press(
        &self,
        _brush: &mut BrushSettings,
        _button: BrushButton,
        _height: f32,
    ) -> bool {
        false
    }

    fn command(
        &self,
        brush: &BrushSettings,
        stamp: BrushStamp,
        button: BrushButton,
    ) -> Box<dyn Command>;
}

pub(crate) struct MapEditingState {
    tool: &'static dyn MapBrush,
    brush: BrushSettings,
    /// Patterns already uploaded as greyscale shapes this session.
    uploaded: HashSet<String>,
    painting: bool,
    /// The last valid ground hit, retained only to keep a stationary stroke
    /// alive across a transient trace miss (for example after raising terrain
    /// into the camera). A moved cursor never paints at this stale position.
    last_hit: Option<crate::sbc::states::state::GroundHit>,
    /// Screen position paired with `last_hit`, in the ray-trace convention.
    last_screen: Option<(f32, f32)>,
    last_apply: Option<Instant>,
    initial_delay_left: f32,
    preview: BrushPreview,
}

impl MapEditingState {
    pub(crate) fn new(tool: &'static dyn MapBrush, brush: BrushSettings) -> Self {
        MapEditingState {
            tool,
            brush,
            uploaded: HashSet::new(),
            painting: false,
            last_hit: None,
            last_screen: None,
            last_apply: None,
            initial_delay_left: tool.initial_delay(),
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

    fn start_painting(&mut self, ctx: &mut StateContext) {
        if self.painting {
            return;
        }
        self.initial_delay_left = self.tool.initial_delay();
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
        if self.brush.pattern_texture.is_none() {
            log::warn!(
                "{} brush cannot paint: no pattern selected",
                self.tool.name()
            );
            return false;
        }
        if !self.tool.is_ready(&self.brush) {
            log::warn!(
                "{} brush cannot paint: incomplete brush settings",
                self.tool.name()
            );
            return false;
        }
        self.tool.prepare(&self.brush, &mut self.uploaded, ctx)
    }

    /// One dab of the brush at world `(x, z)`.
    fn apply(&mut self, ctx: &mut StateContext, x: f32, z: f32, button: i32) {
        if self.brush.pattern_texture.is_none()
            || !self.tool.prepare(&self.brush, &mut self.uploaded, ctx)
        {
            return;
        }
        if !self.can_apply() {
            return;
        }

        ctx.command(self.tool.command(
            &self.brush,
            BrushStamp {
                x,
                z,
                size: self.brush.size,
                rotation: self.brush.rotation,
            },
            BrushButton::from_mouse(button),
        ));
    }
}

impl EditorState for MapEditingState {
    fn name(&self) -> &'static str {
        self.tool.name()
    }

    fn leave(&mut self, ctx: &mut StateContext) {
        self.stop_painting(ctx);
    }

    fn mouse_press(&mut self, ctx: &mut StateContext, x: i32, y: i32, button: i32) -> bool {
        if button != LEFT && button != RIGHT {
            return false;
        }
        let Some(hit) = trace_ground(ctx.interface, x as f32, y as f32) else {
            log::warn!(
                "{} brush cannot paint: cursor did not hit the ground",
                self.tool.name()
            );
            return true;
        };
        if self
            .tool
            .consume_press(&mut self.brush, BrushButton::from_mouse(button), hit.y)
        {
            return true;
        }
        if !self.prepare_paint(ctx) {
            return true;
        }
        self.start_painting(ctx);
        self.last_hit = Some(hit);
        self.last_screen = Some((x as f32, y as f32));
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
        let Ok((alt, _, _, shift)) = ctx.interface.input().get_mod_key_state() else {
            return false;
        };
        if shift {
            self.brush.scale_size(up);
            return true;
        }
        if alt {
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
        let traced = trace_ground(ctx.interface, mouse.x, mouse.y);
        let cursor_has_not_moved = self
            .last_screen
            .is_some_and(|(x, y)| (mouse.x - x).abs() < 0.5 && (mouse.y - y).abs() < 0.5);
        // A stroke begins only on a real ground hit. If the pointer has stayed
        // still, retain that exact hit through a transient ray miss instead of
        // making a click-and-hold randomly stop. Once the pointer moves, a
        // current hit is mandatory: painting the old location would be worse.
        let Some(hit) = traced.or_else(|| cursor_has_not_moved.then_some(self.last_hit).flatten())
        else {
            return;
        };
        if traced.is_some() {
            self.last_hit = Some(hit);
            self.last_screen = Some((mouse.x, mouse.y));
        }
        self.apply(ctx, hit.x, hit.z, button);
    }

    /// Show the brush's actual alpha footprint on the ground under the cursor.
    fn draw_world(&mut self, interface: &NativeInterfaceRef) {
        let Some(pattern) = self.brush.pattern_texture.clone() else {
            return;
        };
        if !self.tool.is_ready(&self.brush) {
            return;
        }
        let Some(mouse) = cursor(interface) else {
            return;
        };
        let traced = trace_ground(interface, mouse.x, mouse.y);
        let cursor_has_not_moved = self
            .last_screen
            .is_some_and(|(x, y)| (mouse.x - x).abs() < 0.5 && (mouse.y - y).abs() < 0.5);
        // While a stationary stroke is active, show the same retained target
        // that `update` keeps painting through a one-frame trace miss.
        let Some(hit) = traced.or_else(|| {
            (self.painting && cursor_has_not_moved)
                .then_some(self.last_hit)
                .flatten()
        }) else {
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
