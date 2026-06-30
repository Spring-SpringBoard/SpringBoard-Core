use serde::Deserialize;

use crate::sbc::command_system::command::Command;
use crate::sbc::command_system::context::Context;
use crate::sbc::command_system::registry::register_command;
use crate::sbc::variables::VariableManager;

/// Adds a variable. 1:1 with `scen_edit/command/add_variable_command.lua`:
/// execute adds (recording the id), unexecute removes.
#[derive(Deserialize, Debug)]
pub struct AddVariableCommand {
    variable: serde_json::Value,
    #[serde(skip)]
    id: Option<i32>,
}

impl Command for AddVariableCommand {
    fn execute(&mut self, ctx: &mut Context) {
        // On redo, reuse the id assigned the first time so the variable returns
        // with the same id (Lua mutates the variable table in place with its id;
        // we clone, so carry the id forward explicitly).
        let mut variable = self.variable.clone();
        if let (Some(id), Some(obj)) = (self.id, variable.as_object_mut()) {
            obj.insert("id".to_string(), serde_json::json!(id));
        }
        let id = ctx.model::<VariableManager>().add_variable(variable);
        self.id = Some(id);
    }

    fn unexecute(&mut self, ctx: &mut Context) {
        if let Some(id) = self.id {
            ctx.model::<VariableManager>().remove_variable(id);
        }
    }
}

register_command!(AddVariableCommand, "AddVariableCommand");
