use std::any::Any;

use spring_native::prelude::{Error, NativeInterfaceRef};

use crate::sbc::command_system::model::{Model, ModelFactory, Models};
use crate::sbc::devconsole::actions::{
    cheat_if_needed, is_cheating, is_global_los, is_god_mode, Action,
};
use crate::sbc::devconsole::log::{LogBuffer, Severity};
use crate::sbc::devconsole::view::{DevConsoleView, ToggleState};
use crate::sbc::keys::is_key;
use crate::sbc::port_flags::{self, UiImpl};

inventory::submit! {
    ModelFactory { make: |iface| Box::new(DevConsoleManager::new(iface)) }
}

/// Lines the UI keeps, matching `cfg.msgCap`.
const MSG_CAP: usize = 200;
/// Lines pulled from the engine's console when the console first opens.
const BACKFILL_LINES: u32 = 50_000;

/// The developer console, a port of `dbg_dev_console_rmlui.lua`.
///
/// Only runs when the native UI is the active one: the Chili and RmlUi consoles
/// serve the other two, and exactly one UI is ever live.
pub(crate) struct DevConsoleManager {
    interface: NativeInterfaceRef,
    enabled: bool,
    view: DevConsoleView,
    buffer: LogBuffer,
    problems_only: bool,
    popup_on_error: bool,
    /// Set whenever the rendered log would change; the DOM is rewritten once
    /// per tick rather than once per line, so a burst stays cheap.
    dirty: bool,
    /// The engine's console buffer is only worth reading once; after a `luaui
    /// reload` rebuilds the view, our own buffer already holds those lines.
    backfilled: bool,
}

impl Model for DevConsoleManager {
    fn as_any_mut(&mut self) -> &mut dyn Any {
        self
    }
}

impl Drop for DevConsoleManager {
    fn drop(&mut self) {
        if self.enabled {
            self.view.dispose(&self.interface);
        }
    }
}

impl DevConsoleManager {
    pub fn new(interface: NativeInterfaceRef) -> Self {
        let enabled = port_flags::ui_impl(&interface) == UiImpl::Rust;
        DevConsoleManager {
            interface,
            enabled,
            view: DevConsoleView::default(),
            buffer: LogBuffer::new(MSG_CAP),
            problems_only: false,
            popup_on_error: true,
            dirty: false,
            backfilled: false,
        }
    }

    pub fn update(&mut self, _models: &mut Models) -> Result<(), Error> {
        if !self.enabled {
            return Ok(());
        }
        if self.view.ensure(&self.interface)? {
            // The engine's own console overlay would double up on ours.
            // `send_commands`' second argument is a *further command*, joined
            // with a newline -- not an argument. Arguments go in the first.
            let _ = self.interface.messages().send_commands("console 0", "");
            if !self.backfilled {
                self.backfill();
                self.backfilled = true;
            }
            self.refresh_toggles()?;
            self.dirty = true;
        }
        if !self.view.is_ready() {
            return Ok(());
        }

        self.process_actions()?;
        if !self.view.is_ready() {
            return Ok(());
        }

        if self.dirty {
            self.view
                .render_log(&self.interface, self.buffer.visible(self.problems_only))?;
            self.view
                .render_error_count(&self.interface, self.buffer.error_count())?;
            self.dirty = false;
        }
        self.view.update(&self.interface)
    }

    /// Seed the console with what the engine logged before RmlUi was up,
    /// otherwise startup errors -- the ones that matter most -- are invisible.
    fn backfill(&mut self) {
        let Ok(entries) = self.interface.messages().get_console_buffer(BACKFILL_LINES) else {
            return;
        };
        for entry in entries {
            if entry.text.is_null() {
                continue;
            }
            let text = unsafe { std::ffi::CStr::from_ptr(entry.text) }.to_string_lossy();
            self.buffer.push(text.trim_end());
        }
    }

    /// A line the engine just logged.
    pub fn add_console_line(&mut self, message: &str) {
        if !self.enabled {
            return;
        }
        let severity = self.buffer.push(message.trim_end());
        self.dirty = true;

        if severity == Severity::Error && self.popup_on_error && !self.view.visible() {
            let _ = self.view.set_visible(&self.interface, true);
        }
    }

    pub fn key_press(&mut self, key_code: i32) -> Result<bool, Error> {
        if !self.enabled || !self.view.is_ready() {
            return Ok(false);
        }
        if is_key(&self.interface, key_code, "f8") {
            let visible = !self.view.visible();
            self.view.set_visible(&self.interface, visible)?;
            self.refresh_toggles()?;
            return Ok(true);
        }
        Ok(false)
    }

    fn process_actions(&mut self) -> Result<(), Error> {
        let actions = self.view.drain_actions();
        if actions.is_empty() {
            return Ok(());
        }
        for action in actions {
            // `luaui reload` tears RmlUi down *synchronously*, freeing this
            // document mid-loop. Nothing below may touch the DOM afterwards;
            // `ensure` rebuilds on the next tick.
            if !self.view.context_is_alive(&self.interface) {
                self.view.forget();
                return Ok(());
            }
            match action {
                Action::Clear => {
                    self.buffer.clear();
                    self.dirty = true;
                }
                Action::FilterProblems => {
                    self.problems_only = !self.problems_only;
                    self.dirty = true;
                }
                Action::TogglePopupOnError => self.popup_on_error = !self.popup_on_error,
                Action::ToggleVisibility => {
                    let visible = !self.view.visible();
                    self.view.set_visible(&self.interface, visible)?;
                }
                Action::ReloadLuaUi => {
                    let _ = self.interface.messages().send_commands("luaui reload", "");
                }
                Action::ReloadLuaRules => {
                    cheat_if_needed(&self.interface);
                    let _ = self
                        .interface
                        .messages()
                        .send_commands("luarules reload", "");
                }
                Action::ToggleCheating => {
                    let _ = self.interface.messages().send_commands("cheat", "");
                }
                Action::ToggleGlobalLos => {
                    cheat_if_needed(&self.interface);
                    let _ = self.interface.messages().send_commands("globallos", "");
                }
                Action::ToggleGodMode => {
                    cheat_if_needed(&self.interface);
                    let _ = self.interface.messages().send_commands("godmode", "");
                }
            }
        }
        if !self.view.context_is_alive(&self.interface) {
            self.view.forget();
            return Ok(());
        }
        self.refresh_toggles()
    }

    fn refresh_toggles(&mut self) -> Result<(), Error> {
        let state = ToggleState {
            problems_only: self.problems_only,
            popup_on_error: self.popup_on_error,
            visible: self.view.visible(),
            cheating: is_cheating(&self.interface),
            global_los: is_global_los(&self.interface),
            god_mode: is_god_mode(&self.interface),
        };
        self.view.render_toggles(&self.interface, state)
    }
}
