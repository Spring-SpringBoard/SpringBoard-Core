use std::any::Any;

use spring_native::prelude::{Error, NativeInterfaceRef};

use crate::sbc::command_system::model::{Model, ModelFactory, Models};
use crate::sbc::keys::is_key;
use crate::sbc::port_flags::{self, UiImpl};
use crate::sbc::states::add_object::{AddObjectState, ObjectKind};
use crate::sbc::states::brush_settings::BrushSettings;
use crate::sbc::states::map_editing::{BrushKind, MapEditingState};
use crate::sbc::states::state::{DefaultState, EditorState, StateContext};

inventory::submit! {
    ModelFactory { make: |iface| Box::new(StateManager::new(iface)) }
}

/// What a view asks the editor to do next. Ports `SB.stateManager:SetState`.
#[derive(Debug, Clone, PartialEq, Eq)]
pub(crate) enum StateRequest {
    Default,
    Brush(BrushKind),
    AddUnit(String),
    AddFeature(String),
}

/// The active state. An enum rather than a boxed trait object so the brush a
/// map state owns stays reachable: the mouse wheel resizes it and the panel has
/// to show the new size.
enum ActiveState {
    Default(DefaultState),
    Brush(MapEditingState),
    AddObject(AddObjectState),
}

impl ActiveState {
    fn as_state(&mut self) -> &mut dyn EditorState {
        match self {
            ActiveState::Default(s) => s,
            ActiveState::Brush(s) => s,
            ActiveState::AddObject(s) => s,
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
            state: ActiveState::Default(DefaultState),
            pending_envelopes: Vec::new(),
            // Disjoint from the panel's id range, so history entries never collide.
            next_cmd_id: 2_000_000,
        }
    }

    pub fn drain_envelopes(&mut self) -> Vec<String> {
        std::mem::take(&mut self.pending_envelopes)
    }

    /// Run `f` against a context and collect whatever it queued.
    fn with_context<R>(
        &mut self,
        f: impl FnOnce(&mut dyn EditorState, &mut StateContext) -> R,
    ) -> R {
        let mut ctx = StateContext::new(&self.interface, &mut self.next_cmd_id);
        let result = f(self.state.as_state(), &mut ctx);
        self.pending_envelopes.extend(ctx.take_envelopes());
        result
    }

    /// Swap states, letting the old one close its command stream first.
    pub fn set_state(&mut self, request: StateRequest, models: &mut Models) {
        if !self.enabled {
            return;
        }
        self.with_context(|state, ctx| state.leave(ctx));

        let brush = models.get::<BrushSettings>().clone();
        let team = local_team(&self.interface);
        let mut state = match request {
            StateRequest::Default => ActiveState::Default(DefaultState),
            StateRequest::Brush(kind) => ActiveState::Brush(MapEditingState::new(kind, brush)),
            StateRequest::AddUnit(def) => {
                ActiveState::AddObject(AddObjectState::new(ObjectKind::Unit, def, team))
            }
            StateRequest::AddFeature(def) => {
                ActiveState::AddObject(AddObjectState::new(ObjectKind::Feature, def, team))
            }
        };

        let mut ctx = StateContext::new(&self.interface, &mut self.next_cmd_id);
        state.as_state().enter(&mut ctx);
        self.pending_envelopes.extend(ctx.take_envelopes());
        log::info!("editor state: {}", state.as_state().name());
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
        if state.brush().revision != model.revision {
            // Whichever side moved last wins; a state only bumps the revision
            // when the user turned the wheel or picked a height.
            if state.brush().revision > model.revision {
                *model = state.brush().clone();
            } else {
                state.set_brush(model.clone());
            }
        } else {
            state.set_brush(model.clone());
        }
    }

    // ── Callins ────────────────────────────────────────────────────

    pub fn update(&mut self) -> Result<(), Error> {
        if !self.enabled {
            return Ok(());
        }
        self.with_context(|state, ctx| state.update(ctx));
        Ok(())
    }

    pub fn mouse_press(&mut self, x: i32, y: i32, button: i32) -> Result<bool, Error> {
        if !self.enabled {
            return Ok(false);
        }
        Ok(self.with_context(|state, ctx| state.mouse_press(ctx, x, y, button)))
    }

    pub fn mouse_release(&mut self, x: i32, y: i32, button: i32) -> Result<(), Error> {
        if !self.enabled {
            return Ok(());
        }
        self.with_context(|state, ctx| state.mouse_release(ctx, x, y, button));
        Ok(())
    }

    pub fn mouse_wheel(&mut self, up: bool, value: f32) -> Result<bool, Error> {
        if !self.enabled {
            return Ok(false);
        }
        Ok(self.with_context(|state, ctx| state.mouse_wheel(ctx, up, value)))
    }

    /// Escape leaves any editing state, as in Lua.
    pub fn key_press(&mut self, key_code: i32) -> Result<bool, Error> {
        if !self.enabled {
            return Ok(false);
        }
        if is_key(&self.interface, key_code, "esc") {
            if matches!(self.state, ActiveState::Default(_)) {
                return Ok(false);
            }
            self.with_context(|state, ctx| state.leave(ctx));
            self.state = ActiveState::Default(DefaultState);
            return Ok(true);
        }
        Ok(self.with_context(|state, ctx| state.key_press(ctx, key_code)))
    }
}

fn local_team(interface: &NativeInterfaceRef) -> i32 {
    interface.player().get_local_team_id().unwrap_or(0)
}
