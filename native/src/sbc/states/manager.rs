use std::any::Any;

use spring_native::prelude::{Error, NativeInterfaceRef};

use crate::sbc::command_system::model::{Model, ModelFactory, Models};
use crate::sbc::keys::is_key;
use crate::sbc::objects::{ObjectKind, SelectionManager};
use crate::sbc::port_flags::{self, UiImpl};
use crate::sbc::states::add_object::{AddObjectState, PlacementConfig};
use crate::sbc::states::brush_settings::BrushSettings;
use crate::sbc::states::manipulate::{DragObjectState, RotateObjectState};
use crate::sbc::states::map_editing::{BrushKind, MapEditingState};
use crate::sbc::states::rectangle_select::RectangleSelectState;
use crate::sbc::states::state::{DefaultState, EditorState, StateContext, Transition};

inventory::submit! {
    ModelFactory { make: |iface| Box::new(StateManager::new(iface)) }
}

/// What a view asks the editor to do next. Ports `SB.stateManager:SetState`.
#[derive(Debug, Clone)]
pub(crate) enum StateRequest {
    Default,
    Brush(BrushKind, String),
    AddUnit(String, i32, PlacementConfig),
    AddFeature(String, i32, PlacementConfig),
}

/// The active state. An enum rather than a boxed trait object so the brush a
/// map state owns stays reachable: the mouse wheel resizes it and the panel has
/// to show the new size.
enum ActiveState {
    Default(DefaultState),
    Brush(MapEditingState),
    AddObject(AddObjectState),
    Drag(DragObjectState),
    Rotate(RotateObjectState),
    RectangleSelect(RectangleSelectState),
}

impl ActiveState {
    fn as_state(&mut self) -> &mut dyn EditorState {
        match self {
            ActiveState::Default(s) => s,
            ActiveState::Brush(s) => s,
            ActiveState::AddObject(s) => s,
            ActiveState::Drag(s) => s,
            ActiveState::Rotate(s) => s,
            ActiveState::RectangleSelect(s) => s,
        }
    }
}

/// Owns the one active editing state and drives it from the engine's callins.
///
/// States never touch the command system: they queue envelopes, which the
/// plugin routes exactly as it routes the panel's, so a brush stroke gets undo
/// for free.
pub(crate) struct StateManager {
    interface: NativeInterfaceRef,
    enabled: bool,
    state: ActiveState,
    pending_envelopes: Vec<String>,
    next_cmd_id: u64,
    /// The one-time editor setup (full spectator view) has been sent.
    editor_view_set: bool,
}

impl Model for StateManager {
    fn as_any_mut(&mut self) -> &mut dyn Any {
        self
    }
}

impl StateManager {
    pub fn new(interface: NativeInterfaceRef) -> Self {
        StateManager {
            interface,
            enabled: port_flags::ui_impl(&interface) == UiImpl::Rust,
            state: ActiveState::Default(DefaultState::default()),
            pending_envelopes: Vec::new(),
            // Disjoint from the panel's id range, so history entries never collide.
            next_cmd_id: 2_000_000,
            editor_view_set: false,
        }
    }

    /// The editor is a spectator; enable full view + full select so every
    /// object is visible and clickable (a plain spectator sees only its team's
    /// LOS, and `GuiTraceRay` then skips features the editor just placed). Lua's
    /// editor relies on the same. Sent once, on the first live tick.
    fn ensure_editor_view(&mut self) {
        if self.editor_view_set {
            return;
        }
        // `specfullview 3` = fullview + fullselect (the action's documented
        // default), so the whole map is revealed and selectable.
        let _ = self
            .interface
            .messages()
            .send_commands("specfullview 3", "");
        self.editor_view_set = true;
    }

    pub fn drain_envelopes(&mut self) -> Vec<String> {
        std::mem::take(&mut self.pending_envelopes)
    }

    /// Draw the active state's world-space cursor overlay (placement ghost, brush
    /// outline). Needs no models, so the plugin can call it straight from
    /// `draw_world`.
    pub fn draw_world(&mut self) {
        if !self.enabled {
            return;
        }
        self.state.as_state().draw_world(&self.interface);
    }

    /// Run `f` against a context, collect what it queued, and apply any state
    /// transition it requested (a drag ending, R starting a rotate).
    fn with_context<R>(
        &mut self,
        models: &mut Models,
        f: impl FnOnce(&mut dyn EditorState, &mut StateContext) -> R,
    ) -> R {
        let (result, transition) = {
            let mut ctx = StateContext::new(&self.interface, models, &mut self.next_cmd_id);
            let result = f(self.state.as_state(), &mut ctx);
            let transition = ctx.take_transition();
            self.pending_envelopes.extend(ctx.take_envelopes());
            (result, transition)
        };
        if let Some(transition) = transition {
            self.apply_transition(transition, models);
        }
        result
    }

    fn apply_transition(&mut self, transition: Transition, models: &mut Models) {
        let mut next = match transition {
            Transition::Default => ActiveState::Default(DefaultState::default()),
            Transition::Drag {
                kind,
                model_id,
                diff_x,
                diff_z,
            } => ActiveState::Drag(DragObjectState::new(kind, model_id, diff_x, diff_z)),
            Transition::Rotate => ActiveState::Rotate(RotateObjectState::new()),
            Transition::RectangleSelect { start_x, start_z } => {
                ActiveState::RectangleSelect(RectangleSelectState::new(start_x, start_z))
            }
        };
        self.enter(&mut next, models);
        self.state = next;
    }

    fn enter(&mut self, state: &mut ActiveState, models: &mut Models) {
        let mut ctx = StateContext::new(&self.interface, models, &mut self.next_cmd_id);
        state.as_state().enter(&mut ctx);
        self.pending_envelopes.extend(ctx.take_envelopes());
        log::info!("editor state: {}", state.as_state().name());
    }

    /// Swap states from a panel request, letting the old one close its stream.
    pub fn set_state(&mut self, request: StateRequest, models: &mut Models) {
        if !self.enabled {
            return;
        }
        self.with_context(models, |state, ctx| state.leave(ctx));

        let mut brush = models.get::<BrushSettings>().clone();
        let mut state = match request {
            StateRequest::Default => ActiveState::Default(DefaultState::default()),
            StateRequest::Brush(kind, paint_mode) => {
                if !paint_mode.is_empty() {
                    brush.texture_paint_mode = paint_mode;
                }
                ActiveState::Brush(MapEditingState::new(kind, brush))
            }
            StateRequest::AddUnit(def, def_id, config) => {
                ActiveState::AddObject(AddObjectState::new(ObjectKind::Unit, def, def_id, config))
            }
            StateRequest::AddFeature(def, def_id, config) => ActiveState::AddObject(
                AddObjectState::new(ObjectKind::Feature, def, def_id, config),
            ),
        };
        self.enter(&mut state, models);
        self.state = state;
    }

    /// Copy the panel's brush into an active brush state, and copy back anything
    /// the state changed (a wheel resize, a right-clicked target height).
    pub fn sync_brush(&mut self, models: &mut Models) {
        if !self.enabled {
            return;
        }
        let ActiveState::Brush(state) = &mut self.state else {
            return;
        };
        let model = models.get::<BrushSettings>();
        if state.brush().revision > model.revision {
            *model = state.brush().clone();
        } else {
            state.set_brush(model.clone());
        }
    }

    // ── Callins ────────────────────────────────────────────────────

    pub fn update(&mut self, models: &mut Models) -> Result<(), Error> {
        if !self.enabled {
            return Ok(());
        }
        self.ensure_editor_view();
        self.with_context(models, |state, ctx| state.update(ctx));
        Ok(())
    }

    pub fn mouse_press(
        &mut self,
        models: &mut Models,
        x: i32,
        y: i32,
        button: i32,
    ) -> Result<bool, Error> {
        if !self.enabled {
            return Ok(false);
        }
        Ok(self.with_context(models, |state, ctx| state.mouse_press(ctx, x, y, button)))
    }

    pub fn mouse_release(
        &mut self,
        models: &mut Models,
        x: i32,
        y: i32,
        button: i32,
    ) -> Result<(), Error> {
        if !self.enabled {
            return Ok(());
        }
        self.with_context(models, |state, ctx| state.mouse_release(ctx, x, y, button));
        Ok(())
    }

    pub fn mouse_move(
        &mut self,
        models: &mut Models,
        x: i32,
        y: i32,
        button: i32,
    ) -> Result<bool, Error> {
        if !self.enabled {
            return Ok(false);
        }
        Ok(self.with_context(models, |state, ctx| state.mouse_move(ctx, x, y, button)))
    }

    pub fn mouse_wheel(
        &mut self,
        models: &mut Models,
        up: bool,
        value: f32,
    ) -> Result<bool, Error> {
        if !self.enabled {
            return Ok(false);
        }
        Ok(self.with_context(models, |state, ctx| state.mouse_wheel(ctx, up, value)))
    }

    /// Escape leaves any editing state, as in Lua.
    pub fn key_press(&mut self, models: &mut Models, key_code: i32) -> Result<bool, Error> {
        if !self.enabled {
            return Ok(false);
        }
        if is_key(&self.interface, key_code, "esc") {
            if matches!(self.state, ActiveState::Default(_)) {
                let selection = models.get::<SelectionManager>();
                if selection.count() == 0 {
                    return Ok(false);
                }
                selection.clear();
                let _ = self.interface.selection().select_unit_array(&[], false);
                return Ok(true);
            }
            self.with_context(models, |state, ctx| state.leave(ctx));
            self.state = ActiveState::Default(DefaultState::default());
            return Ok(true);
        }
        Ok(self.with_context(models, |state, ctx| state.key_press(ctx, key_code)))
    }
}
