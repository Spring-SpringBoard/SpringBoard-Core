//! Placing a unit or a feature, a port of `add_object_state.lua`.
//!
//! Lua's version also brushes several objects at once with a scatter radius and
//! draws a ghost of the object under the cursor. Neither is here: the scatter
//! needs the brush controls that view does not have yet, and the ghost needs a
//! native model-drawing binding.

use crate::sbc::states::state::{trace_ground, EditorState, StateContext};

const LEFT: i32 = 1;
const RIGHT: i32 = 3;

/// Which object list the selection came from.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub(crate) enum ObjectKind {
    Unit,
    Feature,
}

impl ObjectKind {
    /// `AddObjectCommand`'s `objType`, lower-case in the wire format.
    fn wire(self) -> &'static str {
        match self {
            ObjectKind::Unit => "unit",
            ObjectKind::Feature => "feature",
        }
    }
}

pub(crate) struct AddObjectState {
    kind: ObjectKind,
    def_name: String,
    team: i32,
    /// Facing, turned by the mouse wheel as in Lua.
    angle: f32,
}

impl AddObjectState {
    pub(crate) fn new(kind: ObjectKind, def_name: String, team: i32) -> Self {
        AddObjectState {
            kind,
            def_name,
            team,
            angle: 0.0,
        }
    }
}

impl EditorState for AddObjectState {
    fn name(&self) -> &'static str {
        match self.kind {
            ObjectKind::Unit => "add-unit",
            ObjectKind::Feature => "add-feature",
        }
    }

    fn mouse_press(&mut self, ctx: &mut StateContext, x: i32, y: i32, button: i32) -> bool {
        if button == RIGHT {
            // Right-click leaves placement, as Lua's escape does.
            return false;
        }
        if button != LEFT {
            return false;
        }
        let Some(hit) = trace_ground(ctx.interface, x as f32, y as f32) else {
            return true;
        };
        // `objType` and `params` sit directly on the command, not under `opts`.
        ctx.command_fields(
            "AddObjectCommand",
            serde_json::json!({
                "objType": self.kind.wire(),
                "params": {
                    "defName": self.def_name,
                    "pos": { "x": hit.x, "y": hit.y, "z": hit.z },
                    "rot": { "x": 0.0, "y": self.angle, "z": 0.0 },
                    "team": self.team,
                },
            }),
        );
        true
    }

    /// Alt + wheel turns the object being placed.
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
