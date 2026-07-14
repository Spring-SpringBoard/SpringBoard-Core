//! The editing-state interface, a port of `scen_edit/state/abstract_state.lua`.
//!
//! A state owns what the mouse does over the map. Exactly one is active; the
//! `StateManager` swaps them. States never execute commands directly: they push
//! command envelopes onto the [`StateContext`], which the plugin routes through
//! the command system, so undo/redo behaves as it does for the panel.

use spring_native::prelude::NativeInterfaceRef;

use crate::sbc::command_system::command::Command;
use crate::sbc::command_system::model::Models;
use crate::sbc::command_system::SetMultipleCommandModeCommand;

/// What a state may do to the world, and the envelopes it produced this tick.
///
/// Carries the model registry, so a state can read the selection and object
/// positions; `StateManager` is itself a model, so it is lifted out before the
/// callin runs and the rest of the registry stays borrowable here.
pub(crate) struct StateContext<'a> {
    pub interface: &'a NativeInterfaceRef,
    pub models: &'a mut Models,
    commands: Vec<Box<dyn Command>>,
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
    /// Start a box-select from a ground corner the drag began on.
    RectangleSelect {
        start_x: f32,
        start_z: f32,
    },
}

impl<'a> StateContext<'a> {
    pub(crate) fn new(interface: &'a NativeInterfaceRef, models: &'a mut Models) -> Self {
        StateContext {
            interface,
            models,
            commands: Vec::new(),
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
    pub(crate) fn command(&mut self, command: Box<dyn Command>) {
        self.commands.push(command);
    }

    /// Open or close a streaming group: everything between the two lands on the
    /// undo stack as a single entry, which is what makes a brush stroke one undo.
    pub(crate) fn set_multiple_command_mode(&mut self, on: bool) {
        self.commands
            .push(Box::new(SetMultipleCommandModeCommand { state: on }));
    }

    pub(crate) fn take_commands(&mut self) -> Vec<Box<dyn Command>> {
        std::mem::take(&mut self.commands)
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

/// The full trace, for selecting whatever is under the cursor.
pub(crate) fn trace_object(interface: &NativeInterfaceRef, x: f32, y: f32) -> Trace {
    trace(interface, x, y)
}

/// The polled cursor, in the space the traces below expect.
///
/// `get_mouse_state` measures y from the *top* of the window, while the engine's
/// mouse callbacks -- and `trace_screen_ray` -- measure it from the bottom. A
/// press therefore traces correctly straight from its callback, but anything
/// that polls the cursor instead (a held brush, a preview under the cursor) must
/// flip y first, or it traces to the mirrored point.
pub(crate) fn cursor(interface: &NativeInterfaceRef) -> Option<Cursor> {
    let mouse = interface.input().get_mouse_state().ok()?;
    let height = interface.display().get_view_geometry().ok()?.viewSizeY as f32;
    Some(Cursor {
        x: mouse.x,
        y: height - 1.0 - mouse.y,
        left: mouse.left,
        right: mouse.right,
    })
}

/// The cursor position, ready to trace with.
#[derive(Debug, Clone, Copy)]
pub(crate) struct Cursor {
    pub x: f32,
    pub y: f32,
    pub left: bool,
    pub right: bool,
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

    /// The mouse cursor this state wants; `None` leaves the engine's own. The
    /// manager applies it on entry, so no state can leave another's behind.
    fn cursor(&self) -> Option<&'static str> {
        None
    }

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

    /// Draw a world-space cursor overlay (a placement ghost, a brush outline).
    /// Runs in the engine's `draw_world`, where only immediate-mode primitives
    /// render — not the engine model drawer.
    fn draw_world(&mut self, interface: &NativeInterfaceRef) {}
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
    /// A press that landed on empty ground: its screen point and the ground
    /// corner under it. A drag from here box-selects; a release without a drag
    /// clears the selection.
    empty_press: Option<(i32, i32)>,
    empty_start: Option<(f32, f32)>,
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
        self.empty_press = None;
        self.empty_start = None;
        if button != 1 {
            return false;
        }

        let trace = trace_object(ctx.interface, x as f32, y as f32);
        let Some((kind, model_id, hit)) = Self::resolve_hit(ctx, trace) else {
            // A press on empty ground arms a box-select: a drag from here selects
            // what it covers, a release without a drag clears the selection.
            //
            // This must claim the press. The engine only delivers `mouse_move`
            // to whoever took the press, and `mouse_move` is what starts the
            // box-select -- refusing it here handed the drag to the camera and
            // the box never appeared.
            self.empty_press = Some((x, y));
            self.empty_start = trace_ground(ctx.interface, x as f32, y as f32).map(|h| (h.x, h.z));
            return true;
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

    /// Moving the mouse with an already-selected object held begins a drag; from
    /// an empty-ground press, a move past a small threshold begins a box-select.
    fn mouse_move(&mut self, ctx: &mut StateContext, x: i32, y: i32, _button: i32) -> bool {
        use crate::sbc::objects::SelectionManager;
        // Ctrl-drag rotates the selection, as it does in Lua, and takes priority
        // over dragging or box-selecting. R does the same thing from the keyboard.
        if ctx.models.get::<SelectionManager>().count() > 0 {
            let mods = mod_state(ctx.interface);
            if mods.ctrl && !mods.shift {
                self.clicked = None;
                self.empty_press = None;
                ctx.request(Transition::Rotate);
                return true;
            }
        }
        if let (Some((sx, sy)), Some((start_x, start_z))) = (self.empty_press, self.empty_start) {
            const DRAG_THRESHOLD: i32 = 4;
            if (x - sx).abs() > DRAG_THRESHOLD || (y - sy).abs() > DRAG_THRESHOLD {
                self.empty_press = None;
                ctx.request(Transition::RectangleSelect { start_x, start_z });
                return true;
            }
            return false;
        }
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
        // An empty-ground press that never became a drag clears the selection.
        if self.empty_press.take().is_some() {
            self.empty_start = None;
            let sel = ctx.models.get::<SelectionManager>();
            if sel.count() > 0 {
                sel.clear();
            }
            return false;
        }
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

    /// Escape drops the selection.
    ///
    /// Rotation is Ctrl-drag, and only Ctrl-drag. Lua also binds R to it, but the
    /// keyboard entry has no drag to end it: the engine only delivers mouse-move
    /// while a button is held, so a rotate begun from the keyboard sits there
    /// with nothing to drive or finish it. Lua's own comment beside the binding
    /// says the two entries should not both exist.
    fn key_press(&mut self, ctx: &mut StateContext, key_code: i32) -> bool {
        use crate::sbc::objects::SelectionManager;
        if !crate::sbc::keys::is_key(ctx.interface, key_code, "esc") {
            return false;
        }
        let sel = ctx.models.get::<SelectionManager>();
        if sel.count() == 0 {
            return false;
        }
        sel.clear();
        let _ = ctx.interface.selection().select_unit_array(&[], false);
        true
    }
}

/// Modifier-key state, read from the engine. The engine packs it as
/// `shift | ctrl | alt | meta`.
pub(crate) struct ModState {
    pub shift: bool,
    pub ctrl: bool,
}

pub(crate) fn mod_state(interface: &NativeInterfaceRef) -> ModState {
    let bits = interface.input().get_mod_key_state().unwrap_or(0);
    ModState {
        shift: bits & (1 << 0) != 0,
        ctrl: bits & (1 << 1) != 0,
    }
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
