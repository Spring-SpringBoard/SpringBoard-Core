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
    /// The current dirty render should land at the newest line. Selection-only
    /// redraws leave the user's scroll alone.
    pin_log_bottom: bool,
    /// Engine console commands apply after `send_commands`; refresh toolbar
    /// pressed states on the following tick so cheating/god/LOS read back live.
    toggle_refresh_pending: bool,
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
            pin_log_bottom: false,
            toggle_refresh_pending: false,
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
            self.pin_log_bottom = true;
        }
        if !self.view.is_ready() {
            return Ok(());
        }

        if self.toggle_refresh_pending {
            self.toggle_refresh_pending = false;
            self.refresh_toggles()?;
        }

        self.process_actions()?;
        if !self.view.is_ready() {
            return Ok(());
        }
        if self.view.process_selection() {
            self.dirty = true;
        }

        if self.dirty {
            let pin_log_bottom = std::mem::take(&mut self.pin_log_bottom);
            self.view.render_log(
                &self.interface,
                self.buffer.visible(self.problems_only),
                pin_log_bottom,
            )?;
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
        self.pin_log_bottom = true;

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
        if !self.view.visible() {
            return Ok(false);
        }
        let ctrl = self
            .interface
            .input()
            .get_mod_key_state()
            .is_ok_and(|bits| bits & (1 << 1) != 0);
        if ctrl && is_key(&self.interface, key_code, "a") {
            let count = self.buffer.visible(self.problems_only).count();
            self.view.select_all(count);
            self.dirty = true;
            return Ok(true);
        }
        if ctrl && is_key(&self.interface, key_code, "c") {
            self.copy_selection();
            return Ok(true);
        }
        Ok(false)
    }

    fn copy_selection(&self) {
        let Some((start, end)) = self.view.selected_range() else {
            return;
        };
        let text = self
            .buffer
            .visible(self.problems_only)
            .enumerate()
            .filter(|(index, _)| *index >= start && *index <= end)
            .map(|(_, line)| line.text.as_str())
            .collect::<Vec<_>>()
            .join("\n");
        if !text.is_empty() {
            let _ = self.interface.unsynced_ctrl().set_clipboard(&text);
        }
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
                    self.pin_log_bottom = true;
                }
                Action::FilterProblems => {
                    self.problems_only = !self.problems_only;
                    self.dirty = true;
                    self.pin_log_bottom = true;
                    self.toggle_refresh_pending = true;
                }
                Action::Restart => {
                    let _ = self.interface.system_control().restart("", "");
                }
                Action::TogglePopupOnError => {
                    self.popup_on_error = !self.popup_on_error;
                    self.toggle_refresh_pending = true;
                }
                Action::ToggleVisibility => {
                    let visible = !self.view.visible();
                    self.view.set_visible(&self.interface, visible)?;
                    self.toggle_refresh_pending = true;
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
                    self.toggle_refresh_pending = true;
                }
                Action::ToggleGlobalLos => {
                    cheat_if_needed(&self.interface);
                    let _ = self.interface.messages().send_commands("globallos", "");
                    self.toggle_refresh_pending = true;
                }
                Action::ToggleGodMode => {
                    cheat_if_needed(&self.interface);
                    let _ = self.interface.messages().send_commands("godmode", "");
                    self.toggle_refresh_pending = true;
                }
            }
        }
        if !self.view.context_is_alive(&self.interface) {
            self.view.forget();
            return Ok(());
        }
        Ok(())
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
