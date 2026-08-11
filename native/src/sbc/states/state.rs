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

use super::trace::{trace_ground_from_callback, trace_object_from_callback, GroundHit, Trace};

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
    /// Start a box-select from the screen point where the drag began. This can
    /// be over the sky as well as terrain, matching Chili's selection box.
    RectangleSelect {
        start_x: i32,
        start_y: i32,
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

    /// Draw a screen-space overlay after the world. Rectangle selection uses
    /// this rather than requiring both drag corners to land on terrain.
    fn draw_screen(&mut self, interface: &NativeInterfaceRef) {}
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
    /// A press that landed on empty map/sky. A drag from here box-selects; a
    /// release without a drag clears the selection.
    empty_press: Option<(i32, i32)>,
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
        if button != 1 {
            return false;
        }

        let trace = trace_object_from_callback(ctx.interface, x, y);
        let Some((kind, model_id, _hit)) = Self::resolve_hit(ctx, trace) else {
            // A press on empty ground arms a box-select: a drag from here selects
            // what it covers, a release without a drag clears the selection.
            //
            // This must claim the press. The engine only delivers `mouse_move`
            // to whoever took the press, and `mouse_move` is what starts the
            // box-select -- refusing it here handed the drag to the camera and
            // the box never appeared.
            self.empty_press = Some((x, y));
            return true;
        };

        // Match Lua's `TraceScreenRay(..., { onlyCoords = true })`: capture the
        // terrain point beneath the press, not the point where the ray happened
        // to strike the object.  Drag updates also trace terrain; using the
        // object hit here made the first small cursor movement produce a large
        // world-space jump for tall or large objects.
        //
        // At the map edge Lua falls back to the object position when there is
        // no ground hit, which makes the initial offset zero.
        let (diff_x, diff_z) = ctx
            .models
            .get::<ObjectManager>()
            .object_pos(kind, model_id)
            .map(|pos| {
                trace_ground_from_callback(ctx.interface, x, y)
                    .map(|ground| (pos.x - ground.x, pos.z - ground.z))
                    .unwrap_or((0.0, 0.0))
            })
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
        if let Some((start_x, start_y)) = self.empty_press {
            const DRAG_THRESHOLD: i32 = 4;
            if (x - start_x).abs() > DRAG_THRESHOLD || (y - start_y).abs() > DRAG_THRESHOLD {
                self.empty_press = None;
                ctx.request(Transition::RectangleSelect { start_x, start_y });
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

/// Modifier-key state, read from the engine.
pub(crate) struct ModState {
    pub shift: bool,
    pub ctrl: bool,
}

pub(crate) fn mod_state(interface: &NativeInterfaceRef) -> ModState {
    let (_, ctrl, _, shift) = interface
        .input()
        .get_mod_key_state()
        .unwrap_or((false, false, false, false));
    ModState { shift, ctrl }
}
