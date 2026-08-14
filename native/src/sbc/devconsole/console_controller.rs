use std::any::Any;

use spring_native::prelude::{Error, NativeInterfaceRef};

use crate::sbc::command_system::command::{Command, CommandId};
use crate::sbc::command_system::model::{Model, ModelFactory, Models};
use crate::sbc::devconsole::history_model::HistoryModel;
use crate::sbc::devconsole::log::Severity;
use crate::sbc::devconsole::log_model::LogModel;
use crate::sbc::devconsole::status_bar::StatusBar;
use crate::sbc::devconsole::toolbar_actions::{
    is_cheating, is_global_los, is_god_mode, ToolbarActionContext,
};
use crate::sbc::devconsole::view::{ConsoleView, ToggleState};
use crate::sbc::keys::{is_key, KeyMods};
use crate::sbc::objects::SelectionManager;
use crate::sbc::port_flags::{self, UiImpl};

inventory::submit! {
    ModelFactory { make: |iface| Box::new(ConsoleController::new(iface)) }
}

pub(crate) struct ConsoleController {
    interface: NativeInterfaceRef,
    enabled: bool,
    ctrl_pressed: bool,
    log: LogModel,
    history: HistoryModel,
    view: ConsoleView,
    status_bar: StatusBar,
}

impl Model for ConsoleController {
    fn as_any_mut(&mut self) -> &mut dyn Any {
        self
    }
}

impl Drop for ConsoleController {
    fn drop(&mut self) {
        if self.enabled {
            self.view.dispose(&self.interface);
            self.status_bar.dispose(&self.interface);
        }
    }
}

impl ConsoleController {
    fn new(interface: NativeInterfaceRef) -> Self {
        let enabled = port_flags::ui_impl(&interface) == UiImpl::Rust;
        let hidden = std::env::var("SBC_HIDE_CONSOLE").is_ok();
        let mut view = ConsoleView::default();
        if hidden {
            view.set_hidden_at_startup();
        }
        ConsoleController {
            interface,
            enabled,
            ctrl_pressed: false,
            log: LogModel::new(&interface),
            history: HistoryModel::new(),
            view,
            status_bar: StatusBar::new(&interface),
        }
    }

    pub fn update(&mut self, models: &mut Models) -> Result<(), Error> {
        if !self.enabled {
            return Ok(());
        }
        if self.view.create_if_needed(&self.interface)? {
            let _ = self.interface.messages().send_commands("console 0", "");
            self.log.backfill_if_needed(&self.interface);
            self.refresh_toggles()?;
            self.log.mark_dirty();
        }
        if !self.view.is_ready() {
            return Ok(());
        }
        self.status_bar.ensure(&self.interface)?;

        if self.view.take_toggle_refresh() {
            self.refresh_toggles()?;
        }

        self.handle_toolbar_actions()?;
        self.handle_status_actions();
        if !self.view.is_ready() {
            return Ok(());
        }
        self.view.process_log_selection(&mut self.log);
        self.view.render_log(&mut self.log, &self.interface)?;
        self.render_status(models)?;
        Ok(())
    }

    pub(crate) fn record_command(&mut self, id: CommandId, name: &str) {
        self.history.record_command(id, name);
    }

    pub(crate) fn sync_command_history(&mut self, undo_ids: &[CommandId], redo_ids: &[CommandId]) {
        self.history.sync(undo_ids, redo_ids);
    }

    pub(crate) fn drain_commands(&mut self) -> Vec<Box<dyn Command>> {
        self.history.drain_commands()
    }

    pub fn add_console_line(&mut self, message: &str, priority: i32) {
        if !self.enabled {
            return;
        }
        let severity = self.log.add_line(message, priority);
        if severity == Some(Severity::Error) && self.view.popup_on_error() && !self.view.visible() {
            let _ = self.view.set_visible(&self.interface, true);
        }
    }

    pub fn key_press(&mut self, key_code: i32, mods: KeyMods) -> Result<bool, Error> {
        self.note_key_press(key_code);
        if !self.enabled || !self.view.is_ready() {
            return Ok(false);
        }
        if is_key(&self.interface, key_code, "f8") {
            let visible = !self.view.visible();
            self.view.set_visible(&self.interface, visible)?;
            self.refresh_toggles()?;
            return Ok(true);
        }
        if !self.view.visible() {
            return Ok(false);
        }
        let ctrl = self.ctrl_held(mods);
        if ctrl && is_key(&self.interface, key_code, "a") {
            self.view.select_all_log(&mut self.log);
            return Ok(true);
        }
        if ctrl && is_key(&self.interface, key_code, "c") {
            self.view.copy_log_selection(&self.log, &self.interface);
            return Ok(true);
        }
        Ok(false)
    }

    pub fn key_release(&mut self, key_code: i32) -> Result<bool, Error> {
        if is_key(&self.interface, key_code, "ctrl") {
            self.ctrl_pressed = false;
        }
        Ok(false)
    }

    fn handle_toolbar_actions(&mut self) -> Result<(), Error> {
        let actions = self.view.drain_toolbar_actions();
        if actions.is_empty() {
            return Ok(());
        }
        for action in actions {
            if !self.view.context_is_alive(&self.interface) {
                self.view.forget();
                return Ok(());
            }
            let mut context = ToolbarActionContext {
                interface: &self.interface,
                log: &mut self.log,
                view: &mut self.view,
            };
            action.execute(&mut context)?;
        }
        if !self.view.context_is_alive(&self.interface) {
            self.view.forget();
        }
        Ok(())
    }

    fn handle_status_actions(&mut self) {
        let actions = self.status_bar.drain_actions();
        self.history.enqueue_status_actions(actions);
    }

    fn render_status(&mut self, models: &mut Models) -> Result<(), Error> {
        self.status_bar.render(
            &self.interface,
            models.get::<SelectionManager>(),
            self.history.entries(),
        )
    }

    fn refresh_toggles(&self) -> Result<(), Error> {
        let state = ToggleState {
            problems_only: self.log.problems_only(),
            popup_on_error: self.view.popup_on_error(),
            visible: self.view.visible(),
            cheating: is_cheating(&self.interface),
            global_los: is_global_los(&self.interface),
            god_mode: is_god_mode(&self.interface),
        };
        self.view.render_toggles(state)
    }

    fn ctrl_held(&self, mods: KeyMods) -> bool {
        self.ctrl_pressed || mods.ctrl
    }

    fn note_key_press(&mut self, key_code: i32) {
        if is_key(&self.interface, key_code, "ctrl") {
            self.ctrl_pressed = true;
        }
    }
}
