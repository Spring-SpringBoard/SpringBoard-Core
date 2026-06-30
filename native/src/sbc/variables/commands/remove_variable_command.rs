use serde::Deserialize;

use crate::sbc::command_system::command::Command;
use crate::sbc::command_system::context::Context;
use crate::sbc::command_system::registry::register_command;
use crate::sbc::variables::VariableManager;

/// Removes a variable. Ports `scen_edit/command/remove_variable_command.lua`:
/// execute saves the variable then removes it; unexecute re-adds it.
///
/// (The Lua unexecute calls a non-existent `newVariable`, so undo of a remove
/// is broken in Lua; this ports the intended behaviour — re-add the saved
/// variable, rather than replicate the bug.)
#[derive(Deserialize, Debug)]
pub struct RemoveVariableCommand {
    #[serde(rename = "variableID")]
    variable_id: i32,
    #[serde(skip)]
    saved: Option<serde_json::Value>,
}

impl Command for RemoveVariableCommand {
    fn execute(&mut self, ctx: &mut Context) {
        self.saved = ctx
            .model::<VariableManager>()
            .get_variable(self.variable_id)
            .cloned();
        ctx.model::<VariableManager>()
            .remove_variable(self.variable_id);
    }

    fn unexecute(&mut self, ctx: &mut Context) {
        if let Some(v) = self.saved.clone() {
            ctx.model::<VariableManager>().add_variable(v);
        }
    }
}

register_command!(RemoveVariableCommand, "RemoveVariableCommand");
