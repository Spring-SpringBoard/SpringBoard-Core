use std::collections::VecDeque;

use super::command::Command;

pub struct CommandHistory {
    max_history_size: usize,
    undo: VecDeque<Box<dyn Command>>,
    redo: VecDeque<Box<dyn Command>>,
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
    pub fn push_undo(&mut self, cmd: Box<dyn Command>) {
        self.undo.push_back(cmd);
        if self.undo.len() > self.max_history_size {
            self.undo.pop_front();
        }
        self.redo.clear();
    }

    pub fn pop_undo(&mut self) -> Option<Box<dyn Command>> {
        self.undo.pop_back()
    }

    pub fn push_redo(&mut self, cmd: Box<dyn Command>) {
        self.redo.push_back(cmd);
        // Only undo is capped; redo can't exceed it
        debug_assert!(
            self.redo.len() <= self.max_history_size,
            "redo exceeded cap {}",
            self.max_history_size,
        );
    }

    pub fn pop_redo(&mut self) -> Option<Box<dyn Command>> {
        self.redo.pop_back()
    }

    pub fn clear(&mut self) {
        self.undo.clear();
        self.redo.clear();
    }
}
