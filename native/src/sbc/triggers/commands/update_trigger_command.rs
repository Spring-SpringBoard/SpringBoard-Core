use serde::Deserialize;

use crate::sbc::command_system::command::Command;
use crate::sbc::command_system::context::Context;
use crate::sbc::command_system::registry::register_command;
use crate::sbc::triggers::TriggerManager;

/// Updates a trigger in place. 1:1 with
/// `scen_edit/command/update_trigger_command.lua`: execute saves the old trigger
/// then sets the new one (keyed by `trigger.id`); unexecute restores the old.
#[derive(Deserialize, Debug)]
pub struct UpdateTriggerCommand {
    trigger: serde_json::Value,
    #[serde(skip)]
    old: Option<serde_json::Value>,
}

impl UpdateTriggerCommand {
    fn trigger_id(&self) -> Option<i32> {
        self.trigger
            .get("id")
            .and_then(|v| v.as_i64())
            .map(|v| v as i32)
    }
}

impl Command for UpdateTriggerCommand {
    fn execute(&mut self, ctx: &mut Context) {
        let Some(id) = self.trigger_id() else {
            return;
        };
        // Snapshot once: redo re-runs this same instance, so re-capturing here
        // would store the already-updated value.
        if self.old.is_none() {
            self.old = ctx.model::<TriggerManager>().get_trigger(id).cloned();
        }
        ctx.model::<TriggerManager>()
            .set_trigger(id, self.trigger.clone());
    }

    fn unexecute(&mut self, ctx: &mut Context) {
        let Some(id) = self.trigger_id() else {
            return;
        };
        if let Some(old) = self.old.clone() {
            ctx.model::<TriggerManager>().set_trigger(id, old);
        }
    }
}

register_command!(UpdateTriggerCommand, "UpdateTriggerCommand");
