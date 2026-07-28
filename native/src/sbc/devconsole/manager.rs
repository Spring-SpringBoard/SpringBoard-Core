use std::any::Any;
use std::collections::HashMap;

use spring_native::prelude::{Error, NativeInterfaceRef};

use crate::sbc::command_system::command::{Command, CommandId};
use crate::sbc::command_system::model::{Model, ModelFactory, Models};
use crate::sbc::command_system::{ClearUndoRedoCommand, RedoCommand, UndoCommand};
use crate::sbc::devconsole::actions::{
    cheat_if_needed, is_cheating, is_global_los, is_god_mode, Action,
};
use crate::sbc::devconsole::log::Severity;
use crate::sbc::devconsole::session::ConsoleSession;
use crate::sbc::devconsole::status::StatusPresenter;
use crate::sbc::devconsole::view::{DevConsoleView, HistoryCommand, StatusAction, ToggleState};
use crate::sbc::keys::is_key;
use crate::sbc::objects::SelectionManager;
use crate::sbc::port_flags::{self, UiImpl};

inventory::submit! {
    ModelFactory { make: |iface| Box::new(DevConsoleManager::new(iface)) }
}

/// The developer console, a port of `dbg_dev_console_rmlui.lua`.
///
/// Only runs when the native UI is the active one: the Chili and RmlUi consoles
/// serve the other two, and exactly one UI is ever live.
pub(crate) struct DevConsoleManager {
    interface: NativeInterfaceRef,
    enabled: bool,
    view: DevConsoleView,
    console: ConsoleSession,
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
    status: StatusPresenter,
    /// Captions are registered as commands arrive, then projected onto the
    /// command manager's actual undo/redo deques.
    command_captions: HashMap<CommandId, String>,
    command_log: Vec<HistoryCommand>,
    pending_commands: Vec<Box<dyn Command>>,
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
        // The log is uncontrollable text -- timestamps, ids, whatever the engine
        // felt like saying -- so a screenshot with it in shot can never be a
        // stable reference. The harness starts it hidden (F8 still shows it).
        let hidden = std::env::var("SBC_HIDE_CONSOLE").is_ok();
        let mut view = DevConsoleView::default();
        if hidden {
            view.set_hidden_at_startup();
        }
        DevConsoleManager {
            interface,
            enabled,
            view,
            console: ConsoleSession::new(&interface),
            problems_only: false,
            // An error would otherwise pop the console open mid-scenario.
            popup_on_error: !hidden,
            dirty: false,
            pin_log_bottom: false,
            toggle_refresh_pending: false,
            backfilled: false,
            status: StatusPresenter::new(&interface),
            command_captions: HashMap::new(),
            command_log: Vec::new(),
            pending_commands: Vec::new(),
        }
    }

    pub fn update(&mut self, models: &mut Models) -> Result<(), Error> {
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
        self.process_status_actions();
        if !self.view.is_ready() {
            return Ok(());
        }
        if self.view.process_selection() {
            self.dirty = true;
        }

        if self.dirty {
            let pin_log_bottom = std::mem::take(&mut self.pin_log_bottom);
            let lines = self.console.rendered_lines(self.problems_only);
            self.view
                .render_log(&self.interface, lines.into_iter(), pin_log_bottom)?;
            self.view
                .render_error_count(self.console.error_count(self.problems_only))?;
            self.view
                .render_line_count(&self.console.count_text(self.problems_only))?;
            self.dirty = false;
        }
        self.render_status(models)?;
        self.view.update(&self.interface)
    }

    /// Called by SBC once a command has actually crossed the native bridge.
    pub(crate) fn record_command(&mut self, id: CommandId, name: impl Into<String>) {
        let name = name.into();
        // These commands merely move (or empty) the undo/redo cursor. The
        // status list is an edit journal, so it must keep showing the edits
        // being traversed rather than narrating cursor movement.
        if is_history_navigation(&name) {
            return;
        }
        self.command_captions.insert(id, command_caption(&name));
    }

    /// Rebuild the visual history from the source of truth. Undo/redo controls
    /// never add rows: they only move existing entries across the cursor.
    pub(crate) fn sync_command_history(&mut self, undo_ids: &[CommandId], redo_ids: &[CommandId]) {
        self.command_log = project_command_history(&self.command_captions, undo_ids, redo_ids);
    }

    pub(crate) fn drain_commands(&mut self) -> Vec<Box<dyn Command>> {
        std::mem::take(&mut self.pending_commands)
    }

    /// A line the engine just logged.
    pub fn add_console_line(&mut self, message: &str, priority: i32) {
        if !self.enabled {
            return;
        }
        let Some(severity) = self.console.add_live(message, priority, self.problems_only) else {
            return;
        };
        self.dirty = true;
        self.pin_log_bottom = true;

        if severity == Severity::Error && self.popup_on_error && !self.view.visible() {
            let _ = self.view.set_visible(&self.interface, true);
        }
    }

    /// Ctrl+C and Ctrl+A while the console owns them. Runs before the panel,
    /// whose toolbar binds both to Copy and Select All and would swallow them.
    /// The console owns Ctrl+C whenever it has a selection, and Ctrl+A while the
    /// pointer is over it.
    pub fn text_key(&mut self, key_code: i32) -> Result<bool, Error> {
        if !self.enabled || !self.view.is_ready() || !self.view.visible() || !self.ctrl_held() {
            return Ok(false);
        }
        if is_key(&self.interface, key_code, "c") && self.view.selected_range().is_some() {
            self.copy_selection();
            return Ok(true);
        }
        if is_key(&self.interface, key_code, "a") && self.view.hovered(&self.interface) {
            let count = self.console.rendered_count(self.problems_only);
            self.view.select_all(count);
            self.dirty = true;
            return Ok(true);
        }
        Ok(false)
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
        let ctrl = self.ctrl_held();
        if ctrl && is_key(&self.interface, key_code, "a") {
            let count = self.console.rendered_count(self.problems_only);
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

    fn process_status_actions(&mut self) {
        for action in self.view.drain_status_actions() {
            let command: Box<dyn Command> = match action {
                StatusAction::Undo => Box::new(UndoCommand),
                StatusAction::Redo => Box::new(RedoCommand),
                StatusAction::ClearHistory => Box::new(ClearUndoRedoCommand),
            };
            self.pending_commands.push(command);
        }
    }

    fn render_status(&mut self, models: &mut Models) -> Result<(), Error> {
        let status = self
            .status
            .refresh(&self.interface, models.get::<SelectionManager>());
        self.view.render_status(
            &self.interface,
            &status.position,
            status.performance,
            status.system_performance,
            status.version,
            &self.command_log,
        )
    }

    /// Seed the console with what the engine logged before RmlUi was up,
    /// otherwise startup errors -- the ones that matter most -- are invisible.
    fn backfill(&mut self) {
        self.console.backfill(&self.interface);
    }

    fn ctrl_held(&self) -> bool {
        self.interface
            .input()
            .get_mod_key_state()
            .is_ok_and(|(_, ctrl, _, _)| ctrl)
    }

    fn copy_selection(&self) {
        let Some((start, end)) = self.view.selected_range() else {
            return;
        };
        let text = self
            .console
            .rendered_lines(self.problems_only)
            .into_iter()
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
                    self.console.clear();
                    self.dirty = true;
                    self.pin_log_bottom = true;
                }
                Action::FilterProblems => {
                    self.problems_only = !self.problems_only;
                    if self.problems_only {
                        self.console.refresh_problems(&self.interface);
                    }
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

/// The command registry uses Rust/JSON type names; status history is for a
/// person scanning recent work.  Drop the implementation suffix and split
/// words so `AddObjectCommand` becomes `Add Object`.
fn command_caption(name: &str) -> String {
    let name = name.strip_suffix("Command").unwrap_or(name);
    let mut caption = String::with_capacity(name.len() + 4);
    let mut previous: Option<char> = None;
    let chars: Vec<char> = name.chars().collect();
    for (index, current) in chars.iter().copied().enumerate() {
        let next = chars.get(index + 1).copied();
        if current.is_uppercase()
            && previous.is_some_and(|before| before.is_lowercase() || before.is_ascii_digit())
            || current.is_uppercase()
                && previous.is_some_and(|before| before.is_uppercase())
                && next.is_some_and(char::is_lowercase)
        {
            caption.push(' ');
        }
        caption.push(current);
        previous = Some(current);
    }
    caption
}

fn is_history_navigation(name: &str) -> bool {
    matches!(name, "UndoCommand" | "RedoCommand" | "ClearUndoRedoCommand")
}

fn project_command_history(
    captions: &HashMap<CommandId, String>,
    undo_ids: &[CommandId],
    redo_ids: &[CommandId],
) -> Vec<HistoryCommand> {
    undo_ids
        .iter()
        .filter_map(|id| {
            captions.get(id).map(|caption| HistoryCommand {
                caption: caption.clone(),
                undone: false,
            })
        })
        // Redo stores the next command at the back; reverse it to retain the
        // chronological list Chili showed, with the undone suffix greyed out.
        .chain(redo_ids.iter().rev().filter_map(|id| {
            captions.get(id).map(|caption| HistoryCommand {
                caption: caption.clone(),
                undone: true,
            })
        }))
        .collect()
}

#[cfg(test)]
mod tests {
    use std::collections::HashMap;

    use super::{command_caption, is_history_navigation, project_command_history, HistoryCommand};

    #[test]
    fn edit_history_excludes_undo_cursor_navigation() {
        for command in ["UndoCommand", "RedoCommand", "ClearUndoRedoCommand"] {
            assert!(
                is_history_navigation(command),
                "{command} must stay out of edit history"
            );
        }
        assert!(!is_history_navigation("AddObjectCommand"));
        assert_eq!(command_caption("AddObjectCommand"), "Add Object");
    }

    #[test]
    fn history_projection_moves_existing_rows_across_the_undo_cursor() {
        let captions = HashMap::from([
            (1, "Add Object".to_string()),
            (2, "Paint Texture".to_string()),
            (3, "Move Object".to_string()),
        ]);
        let rows = project_command_history(&captions, &[1], &[3, 2]);
        assert_eq!(
            rows,
            vec![
                HistoryCommand {
                    caption: "Add Object".to_string(),
                    undone: false,
                },
                HistoryCommand {
                    caption: "Paint Texture".to_string(),
                    undone: true,
                },
                HistoryCommand {
                    caption: "Move Object".to_string(),
                    undone: true,
                },
            ]
        );
        assert!(project_command_history(&captions, &[], &[]).is_empty());
    }
}
