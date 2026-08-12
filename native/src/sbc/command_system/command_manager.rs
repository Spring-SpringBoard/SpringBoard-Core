use log::warn;

use super::command::{Command, CommandId};
use super::context::{CommandManagerIntent, Context};
use super::history::{CommandHistory, HistoryEntry, HistoryEvent};
use super::streaming_commands::StreamingCommands;

pub struct CommandManager {
    history: CommandHistory,
    stream: StreamingCommands,
    next_command_id: CommandId,
}

impl CommandManager {
    pub fn new(max_history_size: usize) -> Self {
        CommandManager {
            history: CommandHistory::new(max_history_size),
            stream: StreamingCommands::default(),
            next_command_id: 1_000_000,
        }
    }

    pub fn allocate_command_id(&mut self) -> CommandId {
        let id = self.next_command_id;
        self.next_command_id += 1;
        id
    }

    pub(crate) fn history_command_ids(&self) -> (Vec<CommandId>, Vec<CommandId>) {
        self.history.command_ids()
    }

    pub fn execute(
        &mut self,
        mut command: Box<dyn Command>,
        command_id: CommandId,
        ctx: &mut Context,
    ) -> Vec<HistoryEvent> {
        let mut events = Vec::new();
        self.execute_with_current_id(command.as_mut(), command_id, ctx);

        if command.undoable() {
            let entry = HistoryEntry::new(command_id, command);
            if self.stream.is_streaming() {
                events.extend(self.stream.push(entry));
            } else {
                events.extend(self.history.push_undo(entry));
            }
        }

        for intent in std::mem::take(&mut ctx.command_manager_intents) {
            events.extend(self.apply(intent, ctx));
        }
        events
    }

    fn apply(&mut self, intent: CommandManagerIntent, ctx: &mut Context) -> Vec<HistoryEvent> {
        match intent {
            CommandManagerIntent::Undo => self.undo(ctx),
            CommandManagerIntent::Redo => self.redo(ctx),
            CommandManagerIntent::Clear => self.history.clear(),
            CommandManagerIntent::SetMultipleCommandMode(on) => {
                if on {
                    self.stream.start();
                    Vec::new()
                } else if let Some(stopped) = self.stream.stop() {
                    let mut events = vec![HistoryEvent::Merged {
                        cmd_id: stopped.entry.id,
                        source_cmd_ids: stopped.source_cmd_ids,
                    }];
                    events.extend(self.history.push_undo(stopped.entry));
                    events
                } else {
                    Vec::new()
                }
            }
        }
    }

    fn undo(&mut self, ctx: &mut Context) -> Vec<HistoryEvent> {
        if self.stream.is_streaming() {
            warn!("ignoring undo while streaming");
            return Vec::new();
        }
        if let Some(mut entry) = self.history.pop_undo() {
            self.unexecute_with_current_id(entry.command.as_mut(), entry.id, ctx);
            self.history.push_redo(entry);
        }
        Vec::new()
    }

    fn redo(&mut self, ctx: &mut Context) -> Vec<HistoryEvent> {
        if self.stream.is_streaming() {
            warn!("ignoring redo while streaming");
            return Vec::new();
        }
        if let Some(mut entry) = self.history.pop_redo() {
            self.execute_with_current_id(entry.command.as_mut(), entry.id, ctx);
            return self.history.push_undo_from_redo(entry);
        }
        Vec::new()
    }

    fn execute_with_current_id(
        &mut self,
        command: &mut dyn Command,
        command_id: CommandId,
        ctx: &mut Context,
    ) {
        let previous = ctx.current_command_id;
        ctx.current_command_id = command_id;
        command.execute(ctx);
        ctx.current_command_id = previous;
    }

    fn unexecute_with_current_id(
        &mut self,
        command: &mut dyn Command,
        command_id: CommandId,
        ctx: &mut Context,
    ) {
        let previous = ctx.current_command_id;
        ctx.current_command_id = command_id;
        command.unexecute(ctx);
        ctx.current_command_id = previous;
    }
}
