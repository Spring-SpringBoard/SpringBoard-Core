use serde::Deserialize;

use super::super::command::Command;
use super::super::context::{CommandManagerIntent, Context};
use super::super::registry::register_command;

#[derive(Deserialize)]
pub struct SetMultipleCommandModeCommand {
    pub state: bool,
}

impl Command for SetMultipleCommandModeCommand {
    fn execute(&mut self, ctx: &mut Context) {
        ctx.command_manager_intents
            .push(CommandManagerIntent::SetMultipleCommandMode(self.state));
    }

    fn undoable(&self) -> bool {
        false
    }
}

register_command!(
    SetMultipleCommandModeCommand,
    "SetMultipleCommandModeCommand"
);
