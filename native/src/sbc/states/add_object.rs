//! Placing units and features, a port of `add_object_state.lua` and the object
//! side of `brush_object_state.lua`.
//!
//! Two modes, chosen by the view's Add / Brush buttons:
//! - **Set**: one object per click at the cursor.
//! - **Brush**: `amount` objects scattered within `size`, painted while held.
//!
//! Lua's brush also erases objects on right-click (needs a spatial-query
//! binding) and draws a ghost of the object under the cursor (needs a
//! model-draw binding); neither is here.

use std::time::Instant;

use crate::sbc::objects::ObjectKind;
use crate::sbc::states::state::{trace_ground, EditorState, StateContext, Transition};

const LEFT: i32 = 1;
const RIGHT: i32 = 3;

/// How the placement behaves, from the view's fields.
#[derive(Debug, Clone)]
pub(crate) struct PlacementConfig {
    pub team: i32,
    pub brush: bool,
    /// Objects per brush dab.
    pub amount: u32,
    /// Brush radius.
    pub size: f32,
    /// Yaw range the placed object's facing is drawn from, in radians.
    pub yaw_min: f32,
    pub yaw_max: f32,
}

impl Default for PlacementConfig {
    fn default() -> Self {
        PlacementConfig {
            team: 0,
            brush: false,
            amount: 1,
            size: 100.0,
            yaw_min: 0.0,
            yaw_max: 0.0,
        }
    }
}

/// `AddObjectCommand`'s `objType`, lower-case in the wire format.
fn kind_wire(kind: ObjectKind) -> &'static str {
    match kind {
        ObjectKind::Unit => "unit",
        ObjectKind::Feature => "feature",
        ObjectKind::Area => "area",
    }
}

pub(crate) struct AddObjectState {
    kind: ObjectKind,
    def_name: String,
    config: PlacementConfig,
    /// Facing set by the mouse wheel (set mode only).
    angle: f32,
    /// Whether the brush is painting (button held).
    painting: bool,
    last_apply: Option<Instant>,
    /// A tiny PRNG for scatter; deterministic per state, seeded from the clock.
    rng: u64,
}

impl AddObjectState {
    pub(crate) fn new(kind: ObjectKind, def_name: String, config: PlacementConfig) -> Self {
        AddObjectState {
            kind,
            def_name,
            config,
            angle: 0.0,
            painting: false,
            last_apply: None,
            rng: 0x2545_F491_4F6C_DD1D,
        }
    }

    /// xorshift; good enough to scatter a brush.
    fn next_rand(&mut self) -> f32 {
        self.rng ^= self.rng << 13;
        self.rng ^= self.rng >> 7;
        self.rng ^= self.rng << 17;
        (self.rng >> 40) as f32 / (1u64 << 24) as f32
    }

    fn random_yaw(&mut self) -> f32 {
        let (lo, hi) = (self.config.yaw_min, self.config.yaw_max);
        if hi <= lo {
            lo
        } else {
            lo + self.next_rand() * (hi - lo)
        }
    }

    fn place_one(&mut self, ctx: &mut StateContext, x: f32, y: f32, z: f32, yaw: f32) {
        ctx.command_fields(
            "AddObjectCommand",
            serde_json::json!({
                "objType": kind_wire(self.kind),
                "params": {
                    "defName": self.def_name,
                    "pos": { "x": x, "y": y, "z": z },
                    "rot": { "x": 0.0, "y": yaw, "z": 0.0 },
                    "team": self.config.team,
                },
            }),
        );
    }

    /// One dab: a single object in set mode, or `amount` scattered in brush mode.
    fn apply(&mut self, ctx: &mut StateContext, cx: f32, cz: f32) {
        if !self.config.brush {
            if let Some(hit) = ground(ctx, cx, cz) {
                let yaw = self.angle;
                self.place_one(ctx, hit.0, hit.1, hit.2, yaw);
            }
            return;
        }
        let count = self.config.amount.max(1);
        // Wrap the scatter in one undo group.
        ctx.set_multiple_command_mode(true);
        for _ in 0..count {
            let angle = self.next_rand() * std::f32::consts::TAU;
            let radius = self.next_rand().sqrt() * self.config.size * 0.5;
            let (px, pz) = (cx + radius * angle.cos(), cz + radius * angle.sin());
            let yaw = self.random_yaw();
            if let Some(hit) = ground(ctx, px, pz) {
                self.place_one(ctx, hit.0, hit.1, hit.2, yaw);
            }
        }
        ctx.set_multiple_command_mode(false);
    }

    fn can_apply(&mut self) -> bool {
        // Brush repeats about every 0.1s while held, matching Lua's applyDelay.
        let now = Instant::now();
        match self.last_apply {
            Some(last) if now.duration_since(last).as_secs_f32() < 0.1 => false,
            _ => {
                self.last_apply = Some(now);
                true
            }
        }
    }
}

/// Cursor-to-world at a map position, via the ground height.
fn ground(ctx: &StateContext, x: f32, z: f32) -> Option<(f32, f32, f32)> {
    let y = ctx.interface.terrain().get_ground_height(x, z).ok()?;
    Some((x, y, z))
}

impl EditorState for AddObjectState {
    fn name(&self) -> &'static str {
        match self.kind {
            ObjectKind::Unit => "add-unit",
            ObjectKind::Feature => "add-feature",
            ObjectKind::Area => "add-area",
        }
    }

    fn mouse_press(&mut self, ctx: &mut StateContext, x: i32, y: i32, button: i32) -> bool {
        if button == RIGHT {
            // Right-click leaves placement, as Lua's escape does.
            ctx.request(Transition::Default);
            return true;
        }
        if button != LEFT {
            return false;
        }
        let Some(hit) = trace_ground(ctx.interface, x as f32, y as f32) else {
            return true;
        };
        self.painting = true;
        self.last_apply = Some(Instant::now());
        self.apply(ctx, hit.x, hit.z);
        true
    }

    fn mouse_release(&mut self, _ctx: &mut StateContext, _x: i32, _y: i32, _button: i32) -> bool {
        self.painting = false;
        false
    }

    /// Brush mode keeps placing where the cursor is while the button is held.
    fn update(&mut self, ctx: &mut StateContext) {
        if !self.painting || !self.config.brush {
            return;
        }
        let Ok(mouse) = ctx.interface.input().get_mouse_state() else {
            return;
        };
        if !mouse.left {
            self.painting = false;
            return;
        }
        if !self.can_apply() {
            return;
        }
        if let Some(hit) = trace_ground(ctx.interface, mouse.x, mouse.y) {
            self.apply(ctx, hit.x, hit.z);
        }
    }

    /// Alt + wheel turns the object being placed (set mode).
    fn mouse_wheel(&mut self, ctx: &mut StateContext, up: bool, _value: f32) -> bool {
        const ALT: u32 = 1 << 2;
        let Ok(mods) = ctx.interface.input().get_mod_key_state() else {
            return false;
        };
        if mods & ALT == 0 {
            return false;
        }
        self.angle += if up { 0.1 } else { -0.1 };
        true
    }
}
