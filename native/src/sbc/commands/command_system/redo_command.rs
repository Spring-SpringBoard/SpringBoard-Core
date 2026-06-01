use serde::Deserialize;

use crate::sbc::commands::command_system::registry::register_command;

use super::command::Command;
use super::context::{CommandManagerIntent, Context};

// Braced (not unit) struct so it deserializes from the `{className: ...}`
// payload — serde can't build a unit struct from a JSON map.
#[derive(Deserialize)]
pub struct RedoCommand {}

impl Command for RedoCommand {
    fn execute(&mut self, ctx: &mut Context) {
        ctx.command_manager_intents.push(CommandManagerIntent::Redo);
    }

    fn undoable(&self) -> bool {
        false
    }
}

register_command!(RedoCommand, "RedoCommand");
