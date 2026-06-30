use serde::Deserialize;

use crate::sbc::command_system::command::Command;
use crate::sbc::command_system::context::Context;
use crate::sbc::command_system::registry::register_command;
use crate::sbc::triggers::TriggerManager;

/// Removes a trigger. 1:1 with `scen_edit/command/remove_trigger_command.lua`:
/// execute saves the trigger then removes it; unexecute re-adds the saved
/// trigger (which carries its id, so it returns unchanged).
#[derive(Deserialize, Debug)]
pub struct RemoveTriggerCommand {
    #[serde(rename = "triggerID")]
    trigger_id: i32,
    #[serde(skip)]
    saved: Option<serde_json::Value>,
}

impl Command for RemoveTriggerCommand {
    fn execute(&mut self, ctx: &mut Context) {
        self.saved = ctx
            .model::<TriggerManager>()
            .get_trigger(self.trigger_id)
            .cloned();
        ctx.model::<TriggerManager>()
            .remove_trigger(self.trigger_id);
    }

    fn unexecute(&mut self, ctx: &mut Context) {
        if let Some(t) = self.saved.clone() {
            ctx.model::<TriggerManager>().add_trigger(t);
        }
    }
}

register_command!(RemoveTriggerCommand, "RemoveTriggerCommand");
