//! The editing-state interface, a port of `scen_edit/state/abstract_state.lua`.
//!
//! A state owns what the mouse does over the map. Exactly one is active; the
//! `StateManager` swaps them. States never execute commands directly: they push
//! command envelopes onto the [`StateContext`], which the plugin routes through
//! the command system, so undo/redo behaves as it does for the panel.

use spring_native::prelude::NativeInterfaceRef;

use crate::sbc::command_system::model::Models;
use crate::sbc::envelope::{as_preview, envelope, envelope_fields, envelope_with};

/// What a state may do to the world, and the envelopes it produced this tick.
///
/// Carries the model registry, so a state can read the selection and object
/// positions; `StateManager` is itself a model, so it is lifted out before the
/// callin runs and the rest of the registry stays borrowable here.
pub(crate) struct StateContext<'a> {
    pub interface: &'a NativeInterfaceRef,
    pub models: &'a mut Models,
    envelopes: Vec<String>,
    next_cmd_id: &'a mut u64,
    transition: Option<Transition>,
}

/// A state a running state asks the manager to switch to (drag → default, etc.).
pub(crate) enum Transition {
    Default,
    Drag {
        kind: crate::sbc::objects::ObjectKind,
        model_id: i32,
        /// Object position minus cursor position at grab time, kept through drag.
        diff_x: f32,
        diff_z: f32,
    },
    Rotate,
}

impl<'a> StateContext<'a> {
    pub(crate) fn new(
        interface: &'a NativeInterfaceRef,
        models: &'a mut Models,
        next_cmd_id: &'a mut u64,
    ) -> Self {
        StateContext {
            interface,
            models,
            envelopes: Vec::new(),
            next_cmd_id,
            transition: None,
        }
    }

    /// Ask the manager to switch state after this callin returns.
    pub(crate) fn request(&mut self, transition: Transition) {
        self.transition = Some(transition);
    }

    pub(crate) fn take_transition(&mut self) -> Option<Transition> {
        self.transition.take()
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

    /// Like [`command_fields`], but off-history: the command applies to the
    /// engine and never reaches undo. Used to preview a drag on the live object.
    pub(crate) fn command_fields_preview(&mut self, class: &str, fields: serde_json::Value) {
        let e = envelope_fields(class, self.next_cmd_id, fields);
        self.envelopes.extend(as_preview(vec![e]));
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

/// The engine's `hitType`: 0 miss, 1 unit, 2 feature, 3 ground.
const HIT_UNIT: i32 = 1;
const HIT_FEATURE: i32 = 2;
const HIT_GROUND: i32 = 3;

/// What the cursor is over. Ports the several shapes `SB.TraceScreenRay` returns.
#[derive(Debug, Clone, Copy, PartialEq)]
pub(crate) enum Trace {
    Sky,
    Ground(GroundHit),
    Unit { spring_id: i32, hit: GroundHit },
    Feature { spring_id: i32, hit: GroundHit },
}

/// Trace the cursor against units, features and the ground.
fn trace(interface: &NativeInterfaceRef, x: f32, y: f32) -> Trace {
    let Ok((hit_type, hit_id, coords)) = interface
        .camera()
        .trace_screen_ray(x, y, false, false, false, true, 0.0)
    else {
        return Trace::Sky;
    };
    let hit = GroundHit {
        x: coords.x,
        y: coords.y,
        z: coords.z,
    };
    match hit_type {
        HIT_UNIT => Trace::Unit {
            spring_id: hit_id,
            hit,
        },
        HIT_FEATURE => Trace::Feature {
            spring_id: hit_id,
            hit,
        },
        HIT_GROUND => Trace::Ground(hit),
        _ => Trace::Sky,
    }
}

/// The full trace, for selecting whatever is under the cursor.
pub(crate) fn trace_object(interface: &NativeInterfaceRef, x: f32, y: f32) -> Trace {
    trace(interface, x, y)
}

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
    fn mouse_move(&mut self, ctx: &mut StateContext, x: i32, y: i32, button: i32) -> bool {
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

/// The state the editor sits in when nothing else is active: click to select,
/// drag a selected object to move it, Ctrl-drag or R to rotate. A port of
/// `default_state.lua` (minus rectangle select, which is its own state).
#[derive(Default)]
pub(crate) struct DefaultState {
    /// The object pressed this click, resolved to (kind, modelID), plus the
    /// object-to-cursor offset captured at press. A move while it is held starts
    /// a drag; a release without a move selects it.
    clicked: Option<ClickedObject>,
    /// Whether the pressed object was already selected: only then does a move
    /// drag it, matching Lua.
    was_selected: bool,
}

#[derive(Clone, Copy)]
struct ClickedObject {
    kind: crate::sbc::objects::ObjectKind,
    model_id: i32,
    diff_x: f32,
    diff_z: f32,
}

impl DefaultState {
    /// Resolve a trace hit to an editor object, if the click landed on one.
    fn resolve_hit(
        ctx: &mut StateContext,
        trace: Trace,
    ) -> Option<(crate::sbc::objects::ObjectKind, i32, GroundHit)> {
        use crate::sbc::objects::{ObjectKind, ObjectManager};
        let (kind, spring_id, hit) = match trace {
            Trace::Unit { spring_id, hit } => (ObjectKind::Unit, spring_id, hit),
            Trace::Feature { spring_id, hit } => (ObjectKind::Feature, spring_id, hit),
            _ => return None,
        };
        let model_id = ctx
            .models
            .get::<ObjectManager>()
            .model_id_for_spring(kind, spring_id)?;
        Some((kind, model_id, hit))
    }
}

impl EditorState for DefaultState {
    fn name(&self) -> &'static str {
        "default"
    }

    fn mouse_press(&mut self, ctx: &mut StateContext, x: i32, y: i32, button: i32) -> bool {
        use crate::sbc::objects::{ObjectManager, SelectionManager};
        self.clicked = None;
        self.was_selected = false;
        if button != 1 {
            return false;
        }

        let trace = trace_object(ctx.interface, x as f32, y as f32);
        let Some((kind, model_id, hit)) = Self::resolve_hit(ctx, trace) else {
            // A press on empty ground clears the selection, leaving the camera
            // to the engine. (Rectangle select is a separate, unported state.)
            let sel = ctx.models.get::<SelectionManager>();
            if sel.count() > 0 {
                sel.clear();
            }
            return false;
        };

        // Remember the object-to-cursor offset so a drag keeps the grab point.
        let (diff_x, diff_z) = ctx
            .models
            .get::<ObjectManager>()
            .object_pos(kind, model_id)
            .map(|pos| (pos.x - hit.x, pos.z - hit.z))
            .unwrap_or((0.0, 0.0));

        self.was_selected = ctx
            .models
            .get::<SelectionManager>()
            .get(kind)
            .contains(&model_id);
        self.clicked = Some(ClickedObject {
            kind,
            model_id,
            diff_x,
            diff_z,
        });
        true
    }

    /// Moving the mouse with an already-selected object held begins a drag.
    fn mouse_move(&mut self, ctx: &mut StateContext, _x: i32, _y: i32, _button: i32) -> bool {
        let Some(clicked) = self.clicked else {
            return false;
        };
        if !self.was_selected {
            return false;
        }
        ctx.request(Transition::Drag {
            kind: clicked.kind,
            model_id: clicked.model_id,
            diff_x: clicked.diff_x,
            diff_z: clicked.diff_z,
        });
        true
    }

    fn mouse_release(&mut self, ctx: &mut StateContext, _x: i32, _y: i32, _button: i32) -> bool {
        use crate::sbc::objects::{ObjectKind, ObjectManager, SelectionManager};
        let Some(clicked) = self.clicked.take() else {
            return false;
        };
        // Shift toggles the object in the selection; a plain click replaces it.
        let shift = mod_state(ctx.interface).shift;
        {
            let sel = ctx.models.get::<SelectionManager>();
            if shift {
                sel.toggle(clicked.kind, clicked.model_id);
            } else {
                sel.select_one(clicked.kind, clicked.model_id);
            }
        }
        // Mirror the unit selection into the engine for the selection glow.
        // Resolve springIDs first (borrowing ObjectManager), then hand the plain
        // ids to the selection binding, so the two models are never borrowed at
        // once.
        let unit_model_ids = ctx.models.get::<SelectionManager>().get(ObjectKind::Unit);
        let objects = ctx.models.get::<ObjectManager>();
        let spring_ids: Vec<i32> = unit_model_ids
            .into_iter()
            .filter_map(|id| objects.spring_id(ObjectKind::Unit, id))
            .collect();
        let _ = ctx
            .interface
            .selection()
            .select_unit_array(&spring_ids, false);
        false
    }

    /// R begins a rotate on the current selection, matching Lua.
    fn key_press(&mut self, ctx: &mut StateContext, key_code: i32) -> bool {
        use crate::sbc::objects::SelectionManager;
        if !crate::sbc::keys::is_key(ctx.interface, key_code, "r") {
            return false;
        }
        if ctx.models.get::<SelectionManager>().count() == 0 {
            return false;
        }
        ctx.request(Transition::Rotate);
        true
    }
}

/// Modifier-key state, read from the engine.
pub(crate) struct ModState {
    pub shift: bool,
}

pub(crate) fn mod_state(interface: &NativeInterfaceRef) -> ModState {
    let bits = interface.input().get_mod_key_state().unwrap_or(0);
    ModState {
        shift: bits & (1 << 0) != 0,
    }
}
