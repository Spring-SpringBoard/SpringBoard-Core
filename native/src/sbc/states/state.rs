//! The editing-state interface, a port of `scen_edit/state/abstract_state.lua`.
//!
//! A state owns what the mouse does over the map. Exactly one is active; the
//! `StateManager` swaps them. States never execute commands directly: they push
//! command envelopes onto the [`StateContext`], which the plugin routes through
//! the command system, so undo/redo behaves as it does for the panel.

use spring_native::prelude::NativeInterfaceRef;

use crate::sbc::envelope::{envelope, envelope_fields, envelope_with};

/// What a state may do to the world, and the envelopes it produced this tick.
pub(crate) struct StateContext<'a> {
    pub interface: &'a NativeInterfaceRef,
    envelopes: Vec<String>,
    next_cmd_id: &'a mut u64,
}

impl<'a> StateContext<'a> {
    pub(crate) fn new(interface: &'a NativeInterfaceRef, next_cmd_id: &'a mut u64) -> Self {
        StateContext {
            interface,
            envelopes: Vec::new(),
            next_cmd_id,
        }
    }

    /// Queue a command. Executed in order, after the state returns.
    pub(crate) fn command(&mut self, class: &str, opts: serde_json::Value) {
        let e = envelope(class, self.next_cmd_id, opts);
        self.envelopes.push(e);
    }

    /// Queue a command whose payload sits under a key other than `opts`
    /// (`SetHeightmapBrushCommand` takes a `greyscale` object).
    pub(crate) fn command_with(&mut self, class: &str, key: &str, payload: serde_json::Value) {
        let e = envelope_with(class, self.next_cmd_id, key, payload);
        self.envelopes.push(e);
    }

    /// Queue a command whose fields live directly on `data`, with no wrapper
    /// key at all (`AddObjectCommand` takes `objType` and `params`).
    pub(crate) fn command_fields(&mut self, class: &str, fields: serde_json::Value) {
        let e = envelope_fields(class, self.next_cmd_id, fields);
        self.envelopes.push(e);
    }

    /// Open or close a streaming group: everything between the two lands on the
    /// undo stack as a single entry, which is what makes a brush stroke one undo.
    pub(crate) fn set_multiple_command_mode(&mut self, on: bool) {
        let id = *self.next_cmd_id;
        *self.next_cmd_id += 1;
        self.envelopes.push(
            serde_json::json!({
                "tag": "command",
                "data": {
                    "className": "SetMultipleCommandModeCommand",
                    "__cmd_id": id,
                    "state": on,
                }
            })
            .to_string(),
        );
    }

    pub(crate) fn take_envelopes(&mut self) -> Vec<String> {
        std::mem::take(&mut self.envelopes)
    }
}

/// Where the cursor is pointing on the map, in world coordinates.
#[derive(Debug, Clone, Copy, PartialEq)]
pub(crate) struct GroundHit {
    pub x: f32,
    pub y: f32,
    pub z: f32,
}

/// The engine's `hitType` for a ground hit; 0 is a miss, 1 a unit, 2 a feature.
const HIT_GROUND: i32 = 3;

/// Trace the cursor onto the ground. `None` when it points at the sky.
///
/// `only_coords` maps to the engine's `groundOnly`, so a unit standing under the
/// cursor does not shadow the terrain: a brush paints the ground beneath it.
/// `ignore_water` likewise reaches the sea floor rather than the water surface.
pub(crate) fn trace_ground(interface: &NativeInterfaceRef, x: f32, y: f32) -> Option<GroundHit> {
    let (hit_type, _, coords) = interface
        .camera()
        .trace_screen_ray(x, y, true, false, false, true, 0.0)
        .ok()?;
    (hit_type == HIT_GROUND).then_some(GroundHit {
        x: coords.x,
        y: coords.y,
        z: coords.z,
    })
}

#[allow(unused_variables)]
pub(crate) trait EditorState {
    /// Human-readable, for logging and for the state a view wants to be in.
    fn name(&self) -> &'static str;

    fn enter(&mut self, ctx: &mut StateContext) {}
    fn leave(&mut self, ctx: &mut StateContext) {}

    /// Returns true when the state consumed the event.
    fn mouse_press(&mut self, ctx: &mut StateContext, x: i32, y: i32, button: i32) -> bool {
        false
    }
    fn mouse_release(&mut self, ctx: &mut StateContext, x: i32, y: i32, button: i32) -> bool {
        false
    }
    fn mouse_wheel(&mut self, ctx: &mut StateContext, up: bool, value: f32) -> bool {
        false
    }
    fn key_press(&mut self, ctx: &mut StateContext, key_code: i32) -> bool {
        false
    }

    /// Called every tick, so a held button keeps painting.
    fn update(&mut self, ctx: &mut StateContext) {}
}

/// The state the editor sits in when nothing else is active. It handles nothing,
/// which leaves the engine's own camera and selection behaviour in place.
pub(crate) struct DefaultState;

impl EditorState for DefaultState {
    fn name(&self) -> &'static str {
        "default"
    }
}
