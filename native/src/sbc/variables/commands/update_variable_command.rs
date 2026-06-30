use serde::Deserialize;

use crate::sbc::command_system::command::Command;
use crate::sbc::command_system::context::Context;
use crate::sbc::command_system::registry::register_command;
use crate::sbc::variables::VariableManager;

/// Updates a variable. 1:1 with `scen_edit/command/update_variable_command.lua`:
/// execute saves the old value then sets the new; unexecute restores the old.
#[derive(Deserialize, Debug)]
pub struct UpdateVariableCommand {
    variable: serde_json::Value,
    #[serde(skip)]
    old: Option<serde_json::Value>,
}

impl UpdateVariableCommand {
    fn variable_id(&self) -> Option<i32> {
        self.variable
            .get("id")
            .and_then(|v| v.as_i64())
            .map(|v| v as i32)
    }
}

impl Command for UpdateVariableCommand {
    fn execute(&mut self, ctx: &mut Context) {
        let Some(id) = self.variable_id() else {
            return;
        };
        // Snapshot once: redo re-runs this same instance, so re-capturing here
        // would store the already-updated value.
        if self.old.is_none() {
            self.old = ctx.model::<VariableManager>().get_variable(id).cloned();
        }
        ctx.model::<VariableManager>()
            .set_variable(id, self.variable.clone());
    }

    fn unexecute(&mut self, ctx: &mut Context) {
        let Some(id) = self.variable_id() else {
            return;
        };
        if let Some(old) = self.old.clone() {
            ctx.model::<VariableManager>().set_variable(id, old);
        }
    }
}

register_command!(UpdateVariableCommand, "UpdateVariableCommand");
