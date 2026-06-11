use std::collections::VecDeque;

use super::command::{Command, CommandId};

#[derive(Clone, Debug, PartialEq, Eq)]
pub enum HistoryEvent {
    Dropped {
        cmd_id: CommandId,
    },
    Merged {
        cmd_id: CommandId,
        source_cmd_ids: Vec<CommandId>,
    },
    UndoEvicted {
        cmd_id: CommandId,
    },
    RedoCleared {
        cmd_ids: Vec<CommandId>,
    },
    Cleared {
        undo_cmd_ids: Vec<CommandId>,
        redo_cmd_ids: Vec<CommandId>,
    },
}

pub struct CommandHistory {
    max_history_size: usize,
    undo: VecDeque<HistoryEntry>,
    redo: VecDeque<HistoryEntry>,
}

pub(super) struct HistoryEntry {
    pub id: CommandId,
    pub command: Box<dyn Command>,
}

impl HistoryEntry {
    pub fn new(id: CommandId, command: Box<dyn Command>) -> Self {
        HistoryEntry { id, command }
    }
}

impl CommandHistory {
    pub fn new(max_history_size: usize) -> Self {
        CommandHistory {
            max_history_size,
            undo: VecDeque::new(),
            redo: VecDeque::new(),
        }
    }

    /// A new action clears redo (history forks).
    pub(super) fn push_undo(&mut self, entry: HistoryEntry) -> Vec<HistoryEvent> {
        self.push_undo_impl(entry, true)
    }

    pub(super) fn push_undo_from_redo(&mut self, entry: HistoryEntry) -> Vec<HistoryEvent> {
        // Redo is replaying an existing history entry, not forking history.
        self.push_undo_impl(entry, false)
    }

    fn push_undo_impl(&mut self, entry: HistoryEntry, clear_redo: bool) -> Vec<HistoryEvent> {
        self.undo.push_back(entry);
        let mut events = Vec::new();
        if self.undo.len() > self.max_history_size {
            if let Some(evicted) = self.undo.pop_front() {
                events.push(HistoryEvent::UndoEvicted { cmd_id: evicted.id });
            }
        }
        if clear_redo {
            let redo_cmd_ids = take_ids(&mut self.redo);
            if !redo_cmd_ids.is_empty() {
                events.push(HistoryEvent::RedoCleared {
                    cmd_ids: redo_cmd_ids,
                });
            }
        }
        events
    }

    pub(super) fn pop_undo(&mut self) -> Option<HistoryEntry> {
        self.undo.pop_back()
    }

    pub(super) fn push_redo(&mut self, entry: HistoryEntry) {
        self.redo.push_back(entry);
        // Only undo is capped; redo can't exceed it
        debug_assert!(
            self.redo.len() <= self.max_history_size,
            "redo exceeded cap {}",
            self.max_history_size,
        );
    }

    pub(super) fn pop_redo(&mut self) -> Option<HistoryEntry> {
        self.redo.pop_back()
    }

    pub fn clear(&mut self) -> Vec<HistoryEvent> {
        let undo_cmd_ids = take_ids(&mut self.undo);
        let redo_cmd_ids = take_ids(&mut self.redo);
        if undo_cmd_ids.is_empty() && redo_cmd_ids.is_empty() {
            Vec::new()
        } else {
            vec![HistoryEvent::Cleared {
                undo_cmd_ids,
                redo_cmd_ids,
            }]
        }
    }
}

fn take_ids(entries: &mut VecDeque<HistoryEntry>) -> Vec<CommandId> {
    entries.drain(..).map(|entry| entry.id).collect()
}
