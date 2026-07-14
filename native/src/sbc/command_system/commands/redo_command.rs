use serde::{Deserialize, Serialize};

use crate::sbc::command_system::registry::register_command;

use super::super::command::Command;
use super::super::context::{CommandManagerIntent, Context};

#[derive(Deserialize, Serialize)]
pub struct RedoCommand;

impl Command for RedoCommand {
    fn execute(&mut self, ctx: &mut Context) {
        ctx.command_manager_intents.push(CommandManagerIntent::Redo);
    }

    fn undoable(&self) -> bool {
        false
    }
}

register_command!(RedoCommand, "RedoCommand");
