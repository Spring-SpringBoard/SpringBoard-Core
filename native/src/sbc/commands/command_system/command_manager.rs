//! Synced-side command execution + undo/redo stacks.

use log::warn;

use super::command::Command;
use super::context::{CommandManagerIntent, Context};
use super::history::CommandHistory;
use super::streaming_commands::StreamingCommands;

pub struct CommandManager {
    history: CommandHistory,
    stream: StreamingCommands,
}

impl CommandManager {
    pub fn new(max_history_size: usize) -> Self {
        CommandManager {
            history: CommandHistory::new(max_history_size),
            stream: StreamingCommands::default(),
        }
    }

    pub fn execute(&mut self, mut cmd: Box<dyn Command>, ctx: &mut Context) {
        cmd.execute(ctx);

        if cmd.undoable() {
            if self.stream.is_streaming() {
                self.stream.push(cmd);
            } else {
                self.history.push_undo(cmd);
            }
        }

        for intent in std::mem::take(&mut ctx.command_manager_intents) {
            self.apply(intent, ctx);
        }
    }

    fn apply(&mut self, intent: CommandManagerIntent, ctx: &mut Context) {
        match intent {
            CommandManagerIntent::Undo => self.undo(ctx),
            CommandManagerIntent::Redo => self.redo(ctx),
            CommandManagerIntent::Clear => self.history.clear(),
            CommandManagerIntent::SetMultipleCommandMode(on) => {
                if on {
                    self.stream.start();
                } else if let Some(cmd) = self.stream.stop() {
                    self.history.push_undo(cmd);
                }
            }
        }
    }

    fn undo(&mut self, ctx: &mut Context) {
        if self.stream.is_streaming() {
            warn!("ignoring undo while streaming");
            return;
        }
        if let Some(mut cmd) = self.history.pop_undo() {
            cmd.unexecute(ctx);
            self.history.push_redo(cmd);
        }
    }

    fn redo(&mut self, ctx: &mut Context) {
        if self.stream.is_streaming() {
            warn!("ignoring redo while streaming");
            return;
        }
        if let Some(mut cmd) = self.history.pop_redo() {
            cmd.execute(ctx);
            self.history.push_undo(cmd);
        }
    }
}
