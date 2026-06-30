use serde::Deserialize;

use crate::sbc::command_system::command::Command;
use crate::sbc::command_system::context::Context;
use crate::sbc::command_system::registry::register_command;
use crate::sbc::triggers::TriggerManager;

/// Adds a trigger. 1:1 with `scen_edit/command/add_trigger_command.lua`:
/// execute adds (recording the id), unexecute removes.
#[derive(Deserialize, Debug)]
pub struct AddTriggerCommand {
    trigger: serde_json::Value,
    #[serde(skip)]
    id: Option<i32>,
}

impl Command for AddTriggerCommand {
    fn execute(&mut self, ctx: &mut Context) {
        // On redo, reuse the id assigned the first time so the trigger returns
        // with the same id (we clone the data, so carry the id forward).
        let mut trigger = self.trigger.clone();
        if let (Some(id), Some(obj)) = (self.id, trigger.as_object_mut()) {
            obj.insert("id".to_string(), serde_json::json!(id));
        }
        let id = ctx.model::<TriggerManager>().add_trigger(trigger);
        self.id = Some(id);
    }

    fn unexecute(&mut self, ctx: &mut Context) {
        if let Some(id) = self.id {
            ctx.model::<TriggerManager>().remove_trigger(id);
        }
    }
}

register_command!(AddTriggerCommand, "AddTriggerCommand");
