//! Native-module event dispatch.
//!
//! Features register a listener next to their model. `SBC` owns the engine
//! callin boundary, but does not need to grow a dependency on every feature
//! that consumes one of those callins.

use spring_native::prelude::{Error, NativeInterfaceRef};

use crate::sbc::command_system::command::{Command, CommandId};
use crate::sbc::command_system::model::Models;

/// A native-module callin.
#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub(crate) enum Event {
    DrawScreen,
    DrawScreenPost,
    DrawWorld,
    DrawWorldPreUnit,
    KeyPress,
    KeyRelease,
    TextInput,
    MouseMove,
    MousePress,
    MouseRelease,
    MouseWheel,
    ConsoleLine,
    CommandRecorded,
    CommandHistoryChanged,
    CommandApplied,
}

/// Stable identity for each registered listener. It is intentionally separate
/// from implementation type: all cross-feature ordering belongs here.
#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub(crate) enum ListenerId {
    ChonsoleText,
    Chonsole,
    Panel,
    DevConsoleText,
    DevConsole,
    State,
    Screenshot,
    Objects,
}

impl ListenerId {
    /// Cross-feature callin ordering. Unlisted combinations are neutral (0),
    /// not first: negative values run before them and positive values after.
    fn event_priority(self, event: Event) -> i16 {
        match (self, event) {
            (Self::Screenshot, Event::DrawScreen | Event::DrawScreenPost) => -20,
            (Self::State, Event::DrawScreen) => -10,
            (Self::Chonsole, Event::DrawScreen) => 0,
            (Self::Panel, Event::DrawScreen) => 10,

            (Self::ChonsoleText, Event::KeyPress) => -30,
            (Self::DevConsoleText, Event::KeyPress) => -20,
            (Self::Panel, Event::KeyPress) => 0,
            (Self::DevConsole, Event::KeyPress) => 10,
            (Self::Chonsole, Event::KeyPress) => 20,
            (Self::State, Event::KeyPress) => 30,

            (Self::Panel, Event::KeyRelease | Event::TextInput) => -10,
            (Self::Chonsole, Event::KeyRelease | Event::TextInput) => 10,

            (
                Self::Chonsole,
                Event::MouseMove | Event::MousePress | Event::MouseRelease | Event::MouseWheel,
            ) => -10,
            (
                Self::Panel,
                Event::MouseMove | Event::MousePress | Event::MouseRelease | Event::MouseWheel,
            ) => 0,
            (
                Self::State,
                Event::MouseMove | Event::MousePress | Event::MouseRelease | Event::MouseWheel,
            ) => 10,

            _ => 0,
        }
    }

    fn update_slot(self) -> Option<UpdateSlot> {
        match self {
            Self::Chonsole => Some(UpdateSlot::ChonsoleUpdate),
            Self::Panel => Some(UpdateSlot::PanelUpdate),
            Self::DevConsole => Some(UpdateSlot::DevConsoleUpdate),
            Self::State => Some(UpdateSlot::StateUpdate),
            _ => None,
        }
    }

    fn command_drain_slot(self) -> Option<UpdateSlot> {
        match self {
            Self::DevConsole => Some(UpdateSlot::DevConsoleCommands),
            Self::Panel => Some(UpdateSlot::PanelCommands),
            Self::State => Some(UpdateSlot::StateCommands),
            _ => None,
        }
    }
}

/// The complete per-tick lifecycle order. This is deliberately centralized:
/// moving a feature relative to another is a global dependency, not a local
/// implementation detail hidden in either feature.
///
/// Leave gaps for a new operation that belongs between two existing ones.
#[derive(Clone, Copy, Debug, Eq, Ord, PartialEq, PartialOrd)]
#[repr(u16)]
pub(crate) enum UpdateSlot {
    ChonsoleUpdate = 100,
    PanelUpdate = 200,
    DevConsoleUpdate = 300,
    DevConsoleCommands = 350,
    StateUpdate = 400,
    PanelCommands = 500,
    StateCommands = 600,
}

/// A feature-owned handler for native module callins.
///
/// The default methods deliberately do nothing. A feature only declares which
/// callins it owns; [`ListenerId`] centrally defines every cross-feature order.
pub(crate) trait EventListener {
    fn id(&self) -> ListenerId;
    fn handles(&self, event: Event) -> bool;

    fn update(&mut self, _models: &mut Models) -> Result<(), Error> {
        Ok(())
    }
    fn draw_screen(&mut self, _models: &mut Models) -> Result<(), Error> {
        Ok(())
    }
    fn draw_screen_post(&mut self, _models: &mut Models) -> Result<(), Error> {
        Ok(())
    }
    fn draw_world(&mut self, _models: &mut Models) -> Result<(), Error> {
        Ok(())
    }
    fn draw_world_pre_unit(&mut self, _models: &mut Models) -> Result<(), Error> {
        Ok(())
    }
    fn key_press(
        &mut self,
        _models: &mut Models,
        _key_code: i32,
        _scan_code: i32,
        _is_repeat: bool,
    ) -> Result<bool, Error> {
        Ok(false)
    }
    fn key_release(
        &mut self,
        _models: &mut Models,
        _key_code: i32,
        _scan_code: i32,
    ) -> Result<bool, Error> {
        Ok(false)
    }
    fn text_input(&mut self, _models: &mut Models, _utf8: &str) -> Result<bool, Error> {
        Ok(false)
    }
    fn mouse_move(
        &mut self,
        _models: &mut Models,
        _x: i32,
        _y: i32,
        _dx: i32,
        _dy: i32,
        _button: i32,
    ) -> Result<bool, Error> {
        Ok(false)
    }
    fn mouse_press(
        &mut self,
        _models: &mut Models,
        _x: i32,
        _y: i32,
        _button: i32,
    ) -> Result<bool, Error> {
        Ok(false)
    }
    fn mouse_release(
        &mut self,
        _models: &mut Models,
        _x: i32,
        _y: i32,
        _button: i32,
    ) -> Result<(), Error> {
        Ok(())
    }
    fn mouse_wheel(&mut self, _models: &mut Models, _up: bool, _value: f32) -> Result<bool, Error> {
        Ok(false)
    }
    fn console_line(
        &mut self,
        _models: &mut Models,
        _message: &str,
        _level: i32,
    ) -> Result<bool, Error> {
        Ok(false)
    }

    /// Return any typed commands this feature queued. The dispatcher invokes
    /// this in a separate, ordered phase, so producers never know who submits
    /// their commands.
    fn drain_commands(&mut self, _models: &mut Models) -> Vec<Box<dyn Command>> {
        Vec::new()
    }

    /// State commands must be submitted before the current input callin ends;
    /// other producers keep their existing update-tick drain behavior.
    fn flush_commands_after(&self, _event: Event) -> bool {
        false
    }

    /// Observe a completed command after its history and IO consequences have
    /// been applied. Object mirroring uses this to forward engine events.
    fn command_applied(&mut self, _models: &mut Models) {}

    /// A command received a stable ID and display name. The developer console
    /// listens to this, but the command boundary does not know that feature.
    fn command_recorded(&mut self, _models: &mut Models, _id: CommandId, _name: &str) {}

    /// The command manager's undo/redo cursor changed.
    fn command_history_changed(
        &mut self,
        _models: &mut Models,
        _undo_ids: &[CommandId],
        _redo_ids: &[CommandId],
    ) {
    }
}

/// Self-registration hook for feature-owned event listeners.
pub(crate) struct EventListenerFactory {
    pub make: fn(NativeInterfaceRef) -> Box<dyn EventListener>,
}
inventory::collect!(EventListenerFactory);

/// Ordered dispatcher assembled from feature registrations.
pub(crate) struct EventDispatcher {
    listeners: Vec<Box<dyn EventListener>>,
    pending_commands: Vec<Box<dyn Command>>,
}

pub(crate) struct UpdateSchedule {
    steps: Vec<UpdateStep>,
    next: usize,
}

#[derive(Clone, Copy)]
struct UpdateStep {
    listener: usize,
    action: UpdateAction,
}

#[derive(Clone, Copy)]
enum UpdateAction {
    Update,
    DrainCommands,
}

impl EventDispatcher {
    pub(crate) fn new(interface: NativeInterfaceRef) -> Self {
        EventDispatcher {
            listeners: inventory::iter::<EventListenerFactory>
                .into_iter()
                .map(|factory| (factory.make)(interface.clone()))
                .collect(),
            pending_commands: Vec::new(),
        }
    }

    pub(crate) fn begin_update(&self) -> UpdateSchedule {
        let mut ordered = Vec::new();
        for (listener, handler) in self.listeners.iter().enumerate() {
            if let Some(order) = handler.id().update_slot() {
                ordered.push((
                    order,
                    UpdateStep {
                        listener,
                        action: UpdateAction::Update,
                    },
                ));
            }
            if let Some(order) = handler.id().command_drain_slot() {
                ordered.push((
                    order,
                    UpdateStep {
                        listener,
                        action: UpdateAction::DrainCommands,
                    },
                ));
            }
        }
        ordered.sort_unstable_by_key(|(order, _)| *order);
        for window in ordered.windows(2) {
            assert_ne!(window[0].0, window[1].0, "duplicate event schedule slot");
        }
        UpdateSchedule {
            steps: ordered.into_iter().map(|(_, step)| step).collect(),
            next: 0,
        }
    }

    /// Run one listener-owned update operation and return commands that must be
    /// submitted before the next operation. The caller never sees listener
    /// identities or schedule slots.
    pub(crate) fn run_update_step(
        &mut self,
        models: &mut Models,
        schedule: &mut UpdateSchedule,
    ) -> Result<Option<Vec<Box<dyn Command>>>, Error> {
        let Some(step) = schedule.steps.get(schedule.next).copied() else {
            return Ok(None);
        };
        schedule.next += 1;
        match step.action {
            UpdateAction::Update => {
                self.listeners[step.listener].update(models)?;
                Ok(Some(Vec::new()))
            }
            UpdateAction::DrainCommands => {
                Ok(Some(self.listeners[step.listener].drain_commands(models)))
            }
        }
    }

    pub(crate) fn draw_screen(&mut self, models: &mut Models) -> Result<(), Error> {
        for index in self.indices(Event::DrawScreen) {
            self.listeners[index].draw_screen(models)?;
        }
        Ok(())
    }

    pub(crate) fn draw_screen_post(&mut self, models: &mut Models) -> Result<(), Error> {
        for index in self.indices(Event::DrawScreenPost) {
            self.listeners[index].draw_screen_post(models)?;
        }
        Ok(())
    }

    pub(crate) fn draw_world(&mut self, models: &mut Models) -> Result<(), Error> {
        for index in self.indices(Event::DrawWorld) {
            self.listeners[index].draw_world(models)?;
        }
        Ok(())
    }

    pub(crate) fn draw_world_pre_unit(&mut self, models: &mut Models) -> Result<(), Error> {
        for index in self.indices(Event::DrawWorldPreUnit) {
            self.listeners[index].draw_world_pre_unit(models)?;
        }
        Ok(())
    }

    pub(crate) fn key_press(
        &mut self,
        models: &mut Models,
        key_code: i32,
        scan_code: i32,
        is_repeat: bool,
    ) -> Result<bool, Error> {
        for index in self.indices(Event::KeyPress) {
            let handled =
                self.listeners[index].key_press(models, key_code, scan_code, is_repeat)?;
            self.flush_after_listener(index, models, Event::KeyPress);
            if handled {
                return Ok(true);
            }
        }
        Ok(false)
    }

    pub(crate) fn key_release(
        &mut self,
        models: &mut Models,
        key_code: i32,
        scan_code: i32,
    ) -> Result<bool, Error> {
        for index in self.indices(Event::KeyRelease) {
            let handled = self.listeners[index].key_release(models, key_code, scan_code)?;
            self.flush_after_listener(index, models, Event::KeyRelease);
            if handled {
                return Ok(true);
            }
        }
        Ok(false)
    }

    pub(crate) fn text_input(&mut self, models: &mut Models, utf8: &str) -> Result<bool, Error> {
        for index in self.indices(Event::TextInput) {
            let handled = self.listeners[index].text_input(models, utf8)?;
            self.flush_after_listener(index, models, Event::TextInput);
            if handled {
                return Ok(true);
            }
        }
        Ok(false)
    }

    pub(crate) fn mouse_move(
        &mut self,
        models: &mut Models,
        x: i32,
        y: i32,
        dx: i32,
        dy: i32,
        button: i32,
    ) -> Result<bool, Error> {
        for index in self.indices(Event::MouseMove) {
            let handled = self.listeners[index].mouse_move(models, x, y, dx, dy, button)?;
            self.flush_after_listener(index, models, Event::MouseMove);
            if handled {
                return Ok(true);
            }
        }
        Ok(false)
    }

    pub(crate) fn mouse_press(
        &mut self,
        models: &mut Models,
        x: i32,
        y: i32,
        button: i32,
    ) -> Result<bool, Error> {
        for index in self.indices(Event::MousePress) {
            let handled = self.listeners[index].mouse_press(models, x, y, button)?;
            self.flush_after_listener(index, models, Event::MousePress);
            if handled {
                return Ok(true);
            }
        }
        Ok(false)
    }

    pub(crate) fn mouse_release(
        &mut self,
        models: &mut Models,
        x: i32,
        y: i32,
        button: i32,
    ) -> Result<(), Error> {
        for index in self.indices(Event::MouseRelease) {
            self.listeners[index].mouse_release(models, x, y, button)?;
            self.flush_after_listener(index, models, Event::MouseRelease);
        }
        Ok(())
    }

    pub(crate) fn mouse_wheel(
        &mut self,
        models: &mut Models,
        up: bool,
        value: f32,
    ) -> Result<bool, Error> {
        for index in self.indices(Event::MouseWheel) {
            let handled = self.listeners[index].mouse_wheel(models, up, value)?;
            self.flush_after_listener(index, models, Event::MouseWheel);
            if handled {
                return Ok(true);
            }
        }
        Ok(false)
    }

    pub(crate) fn console_line(
        &mut self,
        models: &mut Models,
        message: &str,
        level: i32,
    ) -> Result<bool, Error> {
        for index in self.indices(Event::ConsoleLine) {
            let handled = self.listeners[index].console_line(models, message, level)?;
            self.flush_after_listener(index, models, Event::ConsoleLine);
            if handled {
                return Ok(true);
            }
        }
        Ok(false)
    }

    pub(crate) fn take_commands(&mut self) -> Vec<Box<dyn Command>> {
        std::mem::take(&mut self.pending_commands)
    }

    pub(crate) fn command_applied(&mut self, models: &mut Models) {
        for index in self.indices(Event::CommandApplied) {
            self.listeners[index].command_applied(models);
        }
    }

    pub(crate) fn command_recorded(&mut self, models: &mut Models, id: CommandId, name: &str) {
        for index in self.indices(Event::CommandRecorded) {
            self.listeners[index].command_recorded(models, id, name);
        }
    }

    pub(crate) fn command_history_changed(
        &mut self,
        models: &mut Models,
        undo_ids: &[CommandId],
        redo_ids: &[CommandId],
    ) {
        for index in self.indices(Event::CommandHistoryChanged) {
            self.listeners[index].command_history_changed(models, undo_ids, redo_ids);
        }
    }

    fn flush_after_listener(&mut self, index: usize, models: &mut Models, event: Event) {
        if self.listeners[index].flush_commands_after(event) {
            self.pending_commands
                .extend(self.listeners[index].drain_commands(models));
        }
    }

    fn indices(&self, event: Event) -> Vec<usize> {
        let mut indices = self
            .listeners
            .iter()
            .enumerate()
            .filter(|(_, listener)| listener.handles(event))
            .map(|(index, listener)| (listener.id().event_priority(event), index))
            .collect::<Vec<_>>();
        indices.sort_unstable();
        indices.into_iter().map(|(_, index)| index).collect()
    }
}
