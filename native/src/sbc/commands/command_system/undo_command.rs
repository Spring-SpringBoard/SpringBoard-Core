use serde::Deserialize;

use super::command::Command;
use super::context::{CommandManagerIntent, Context};
use super::registry::register_command;

// Braced (not unit) struct so it deserializes from the `{className: ...}`
// payload — serde can't build a unit struct from a JSON map.
#[derive(Deserialize)]
pub struct UndoCommand {}

impl Command for UndoCommand {
    fn execute(&mut self, ctx: &mut Context) {
        ctx.command_manager_intents.push(CommandManagerIntent::Undo);
    }

    fn undoable(&self) -> bool {
        false
    }
}

register_command!(UndoCommand, "UndoCommand");
