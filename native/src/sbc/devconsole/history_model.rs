use std::collections::HashMap;

use crate::sbc::command_system::command::{Command, CommandId};
use crate::sbc::command_system::{ClearUndoRedoCommand, RedoCommand, UndoCommand};
use crate::sbc::devconsole::status_model::StatusBarAction;

#[derive(Clone, Debug, PartialEq, Eq)]
pub(super) struct HistoryEntry {
    pub caption: String,
    pub undone: bool,
}

pub(super) struct HistoryModel {
    captions: HashMap<CommandId, String>,
    entries: Vec<HistoryEntry>,
    pending_commands: Vec<Box<dyn Command>>,
}

impl HistoryModel {
    pub(super) fn new() -> Self {
        Self {
            captions: HashMap::new(),
            entries: Vec::new(),
            pending_commands: Vec::new(),
        }
    }

    pub(super) fn record_command(&mut self, id: CommandId, name: &str) {
        if is_history_navigation(name) {
            return;
        }
        self.captions.insert(id, command_caption(name));
    }

    pub(super) fn sync(&mut self, undo_ids: &[CommandId], redo_ids: &[CommandId]) {
        self.entries = project_history(&self.captions, undo_ids, redo_ids);
    }

    pub(super) fn entries(&self) -> &[HistoryEntry] {
        &self.entries
    }

    pub(super) fn enqueue_status_actions(&mut self, actions: Vec<StatusBarAction>) {
        for action in actions {
            let command: Box<dyn Command> = match action {
                StatusBarAction::Undo => Box::new(UndoCommand),
                StatusBarAction::Redo => Box::new(RedoCommand),
                StatusBarAction::ClearHistory => Box::new(ClearUndoRedoCommand),
            };
            self.pending_commands.push(command);
        }
    }

    pub(super) fn drain_commands(&mut self) -> Vec<Box<dyn Command>> {
        std::mem::take(&mut self.pending_commands)
    }
}

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

fn project_history(
    captions: &HashMap<CommandId, String>,
    undo_ids: &[CommandId],
    redo_ids: &[CommandId],
) -> Vec<HistoryEntry> {
    undo_ids
        .iter()
        .filter_map(|id| {
            captions.get(id).map(|caption| HistoryEntry {
                caption: caption.clone(),
                undone: false,
            })
        })
        .chain(redo_ids.iter().rev().filter_map(|id| {
            captions.get(id).map(|caption| HistoryEntry {
                caption: caption.clone(),
                undone: true,
            })
        }))
        .collect()
}

#[cfg(test)]
mod tests {
    use std::collections::HashMap;

    use super::{command_caption, is_history_navigation, project_history, HistoryEntry};

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
        let rows = project_history(&captions, &[1], &[3, 2]);
        assert_eq!(
            rows,
            vec![
                HistoryEntry {
                    caption: "Add Object".to_string(),
                    undone: false,
                },
                HistoryEntry {
                    caption: "Paint Texture".to_string(),
                    undone: true,
                },
                HistoryEntry {
                    caption: "Move Object".to_string(),
                    undone: true,
                },
            ]
        );
        assert!(project_history(&captions, &[], &[]).is_empty());
    }
}
