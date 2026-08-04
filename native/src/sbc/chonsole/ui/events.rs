use spring_native::prelude::{Error, NativeInterfaceRef};

use crate::sbc::chonsole::commands::ChonsoleCore;
use crate::sbc::keys::{is_key, KeyMods};

use super::view::ChonsoleView;

pub(super) enum KeyOutcome {
    Unhandled,
    Handled,
    Execute(String),
}

#[derive(Default)]
pub(super) struct ChonsoleEvents {
    history: HistoryCursor,
    modifiers: TrackedModifiers,
}

impl ChonsoleEvents {
    pub(super) fn reset_history_cursor(&mut self) {
        self.history.reset();
    }

    pub(super) fn key_press(
        &mut self,
        interface: &NativeInterfaceRef,
        core: &ChonsoleCore,
        view: &mut ChonsoleView,
        key_code: i32,
        key_mods: KeyMods,
    ) -> Result<KeyOutcome, Error> {
        self.modifiers.key_down(interface, key_code);
        if is_key(interface, key_code, "f10") {
            view.toggle(interface)?;
            return Ok(KeyOutcome::Handled);
        }
        if !view.visible()
            && (is_key(interface, key_code, "enter") || is_key(interface, key_code, "numpad_enter"))
        {
            view.set_visible(interface, true)?;
            view.refresh(interface, core)?;
            return Ok(KeyOutcome::Handled);
        }
        if !view.visible() {
            return Ok(KeyOutcome::Unhandled);
        }
        if is_key(interface, key_code, "esc") {
            view.clear_input();
            view.set_visible(interface, false)?;
            return Ok(KeyOutcome::Handled);
        }
        if is_key(interface, key_code, "enter") || is_key(interface, key_code, "numpad_enter") {
            return Ok(KeyOutcome::Execute(view.take_input()));
        }
        if self.text_key(interface, core, view, key_code, key_mods)? {
            return Ok(KeyOutcome::Handled);
        }
        let mods = ModState::read(key_mods, self.modifiers);
        if mods.ctrl && is_key(interface, key_code, "u") {
            self.reset_history_cursor();
            view.delete_to_start();
            view.refresh(interface, core)?;
            return Ok(KeyOutcome::Handled);
        }
        if mods.ctrl && is_key(interface, key_code, "k") {
            self.reset_history_cursor();
            view.delete_to_end();
            view.refresh(interface, core)?;
            return Ok(KeyOutcome::Handled);
        }
        if mods.ctrl && is_key(interface, key_code, "w") {
            self.reset_history_cursor();
            view.delete_prev_word();
            view.refresh(interface, core)?;
            return Ok(KeyOutcome::Handled);
        }
        if is_key(interface, key_code, "backspace") {
            self.reset_history_cursor();
            view.pop_input();
            view.refresh(interface, core)?;
            return Ok(KeyOutcome::Handled);
        }
        if is_key(interface, key_code, "delete") {
            self.reset_history_cursor();
            if mods.ctrl {
                view.delete_next_word();
            } else {
                view.delete_input();
            }
            view.refresh(interface, core)?;
            return Ok(KeyOutcome::Handled);
        }
        if is_key(interface, key_code, "left") {
            if mods.ctrl {
                view.move_prev_word(mods.shift);
            } else {
                view.move_left(mods.shift);
            }
            view.refresh(interface, core)?;
            return Ok(KeyOutcome::Handled);
        }
        if is_key(interface, key_code, "right") {
            if mods.ctrl {
                view.move_next_word(mods.shift);
            } else {
                view.move_right(mods.shift);
            }
            view.refresh(interface, core)?;
            return Ok(KeyOutcome::Handled);
        }
        if is_key(interface, key_code, "home") {
            view.move_home(mods.shift);
            view.refresh(interface, core)?;
            return Ok(KeyOutcome::Handled);
        }
        if is_key(interface, key_code, "end") {
            view.move_end(mods.shift);
            view.refresh(interface, core)?;
            return Ok(KeyOutcome::Handled);
        }
        if is_key(interface, key_code, "up") {
            if !view.select_prev_suggestion(core, 1) {
                self.history_prev(core.history(), view);
            }
            view.refresh(interface, core)?;
            return Ok(KeyOutcome::Handled);
        }
        if is_key(interface, key_code, "down") {
            if !view.select_next_suggestion(core, 1) {
                self.history_next(core.history(), view);
            }
            view.refresh(interface, core)?;
            return Ok(KeyOutcome::Handled);
        }
        if is_key(interface, key_code, "pageup") {
            let _ = view.select_prev_suggestion(core, 10);
            view.refresh(interface, core)?;
            return Ok(KeyOutcome::Handled);
        }
        if is_key(interface, key_code, "pagedown") {
            let _ = view.select_next_suggestion(core, 10);
            view.refresh(interface, core)?;
            return Ok(KeyOutcome::Handled);
        }
        if is_key(interface, key_code, "tab") {
            self.reset_history_cursor();
            if mods.shift {
                let _ = view.select_prev_suggestion(core, 1);
            } else {
                let _ = view.select_next_suggestion(core, 1);
            }
            view.refresh(interface, core)?;
            return Ok(KeyOutcome::Handled);
        }

        // Text entry arrives through TextInput. While the console is open,
        // swallow the originating keypress so game/editor shortcuts never see
        // raw letter keys before text_input inserts the printable character.
        Ok(KeyOutcome::Handled)
    }

    /// Text selection ownership is checked ahead of every other SBC surface,
    /// so a visible Chonsole selection cannot be stolen by a panel or the
    /// developer console's Ctrl+A/Ctrl+X/Ctrl+V bindings.
    pub(super) fn text_key(
        &mut self,
        interface: &NativeInterfaceRef,
        core: &ChonsoleCore,
        view: &mut ChonsoleView,
        key_code: i32,
        key_mods: KeyMods,
    ) -> Result<bool, Error> {
        if !view.visible() || !ModState::read(key_mods, self.modifiers).ctrl {
            return Ok(false);
        }
        if is_key(interface, key_code, "a") {
            view.select_all();
            view.refresh(interface, core)?;
            return Ok(true);
        }
        if is_key(interface, key_code, "c") {
            if let Some(text) = view.selected_text() {
                let _ = interface.unsynced_ctrl().set_clipboard(text);
            }
            return Ok(true);
        }
        if is_key(interface, key_code, "x") {
            if let Some(text) = view.selected_text() {
                let _ = interface.unsynced_ctrl().set_clipboard(text);
                self.reset_history_cursor();
                view.delete_input();
                view.refresh(interface, core)?;
            }
            return Ok(true);
        }
        if is_key(interface, key_code, "v") {
            let pasted = interface
                .unsynced_read()
                .get_clipboard()?
                .unwrap_or_default();
            let pasted = printable_text(&pasted);
            if !pasted.is_empty() {
                self.reset_history_cursor();
                view.push_input(&pasted);
                view.refresh(interface, core)?;
            }
            return Ok(true);
        }
        Ok(false)
    }

    pub(super) fn key_release(
        &mut self,
        interface: &NativeInterfaceRef,
        view: &mut ChonsoleView,
        key_code: i32,
        scan_code: i32,
    ) -> Result<bool, Error> {
        let _ = scan_code;
        self.modifiers.key_up(interface, key_code);
        if !view.visible() {
            return Ok(false);
        }
        let _ = view.process_key_up(interface, key_code)?;
        Ok(true)
    }

    pub(super) fn text_input(
        &mut self,
        interface: &NativeInterfaceRef,
        core: &ChonsoleCore,
        view: &mut ChonsoleView,
        utf8: &str,
    ) -> Result<bool, Error> {
        if !view.visible() {
            return Ok(false);
        }
        let printable = printable_text(utf8);
        if printable.is_empty() {
            return Ok(true);
        }
        self.reset_history_cursor();
        view.push_input(&printable);
        view.refresh(interface, core)?;
        let _ = view.process_text_input(interface, &printable)?;
        Ok(true)
    }

    fn history_prev(&mut self, history: &[String], view: &mut ChonsoleView) {
        if let Some(input) = self.history.prev(history, view.input()) {
            view.set_input(input);
        }
    }

    fn history_next(&mut self, history: &[String], view: &mut ChonsoleView) {
        if let Some(input) = self.history.next(history) {
            view.set_input(input);
        }
    }
}

fn printable_text(text: &str) -> String {
    text.chars().filter(|ch| !ch.is_control()).collect()
}

#[derive(Copy, Clone, Default)]
struct ModState {
    shift: bool,
    ctrl: bool,
}

impl ModState {
    fn read(mods: KeyMods, tracked: TrackedModifiers) -> Self {
        ModState {
            shift: tracked.shift || mods.shift,
            ctrl: tracked.ctrl || mods.ctrl,
        }
    }
}

#[derive(Copy, Clone, Default)]
struct TrackedModifiers {
    shift: bool,
    ctrl: bool,
}

impl TrackedModifiers {
    fn key_down(&mut self, interface: &NativeInterfaceRef, key_code: i32) {
        if is_key(interface, key_code, "shift") {
            self.shift = true;
        }
        if is_key(interface, key_code, "ctrl") {
            self.ctrl = true;
        }
    }

    fn key_up(&mut self, interface: &NativeInterfaceRef, key_code: i32) {
        if is_key(interface, key_code, "shift") {
            self.shift = false;
        }
        if is_key(interface, key_code, "ctrl") {
            self.ctrl = false;
        }
    }
}

#[derive(Default)]
struct HistoryCursor {
    prefix: Option<String>,
    matches: Vec<usize>,
    pos: Option<usize>,
}

impl HistoryCursor {
    fn reset(&mut self) {
        self.prefix = None;
        self.matches.clear();
        self.pos = None;
    }

    fn prev(&mut self, history: &[String], current_input: &str) -> Option<String> {
        self.ensure(history, current_input);
        if self.matches.is_empty() {
            return None;
        }
        let next_pos = match self.pos {
            Some(pos) if pos > 0 => pos - 1,
            Some(pos) => pos,
            None => self.matches.len() - 1,
        };
        self.pos = Some(next_pos);
        history.get(self.matches[next_pos]).cloned()
    }

    fn next(&mut self, history: &[String]) -> Option<String> {
        let prefix = self.prefix.clone()?;
        let pos = self.pos?;
        if pos + 1 < self.matches.len() {
            self.pos = Some(pos + 1);
            return history.get(self.matches[pos + 1]).cloned();
        }
        self.pos = None;
        Some(prefix)
    }

    fn ensure(&mut self, history: &[String], current_input: &str) {
        if self.prefix.is_some() {
            return;
        }
        let prefix = current_input.to_string();
        self.matches = history
            .iter()
            .enumerate()
            .filter_map(|(idx, item)| item.starts_with(&prefix).then_some(idx))
            .collect();
        self.prefix = Some(prefix);
        self.pos = None;
    }
}
