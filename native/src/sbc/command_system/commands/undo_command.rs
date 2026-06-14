use serde::Deserialize;

use super::super::command::Command;
use super::super::context::{CommandManagerIntent, Context};
use super::super::registry::register_command;

#[derive(Deserialize)]
pub struct UndoCommand;

impl Command for UndoCommand {
    fn execute(&mut self, ctx: &mut Context) {
        ctx.command_manager_intents.push(CommandManagerIntent::Undo);
    }

    fn undoable(&self) -> bool {
        false
    }
}

register_command!(UndoCommand, "UndoCommand");
