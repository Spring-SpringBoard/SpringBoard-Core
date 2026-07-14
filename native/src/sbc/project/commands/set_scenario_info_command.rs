use serde::{Deserialize, Serialize};

use crate::sbc::command_system::command::Command;
use crate::sbc::command_system::context::Context;
use crate::sbc::command_system::registry::register_command;
use crate::sbc::project::model::scenario_info_manager::{ScenarioInfo, ScenarioInfoPatch};
use crate::sbc::project::ScenarioInfoManager;

/// Sets scenario metadata. 1:1 with
/// `scen_edit/command/set_scenario_info_command.lua`: execute snapshots the full
/// old state (once) then applies the patch; unexecute restores the snapshot.
#[derive(Deserialize, Serialize, Debug)]
pub struct SetScenarioInfoCommand {
    data: ScenarioInfoPatch,
    #[serde(skip)]
    old: Option<ScenarioInfo>,
}

impl SetScenarioInfoCommand {
    /// Construct from a `data`/`ScenarioInfoPatch` payload. Transitional: the
    /// patch becomes a typed constructor per docs/porting/todo.md (concrete-commands).
    pub(crate) fn from_data(data: serde_json::Value) -> Option<Self> {
        serde_json::from_value(data)
            .ok()
            .map(|data| Self { data, old: None })
    }
}

impl Command for SetScenarioInfoCommand {
    fn serialize_log(&self) -> serde_json::Value {
        serde_json::to_value(self).unwrap_or(serde_json::Value::Null)
    }

    fn execute(&mut self, ctx: &mut Context) {
        // Snapshot once: re-running (redo) must restore to the same pre-command
        // state on a later undo, matching Lua's `if not self.oldData` guard.
        if self.old.is_none() {
            self.old = Some(ctx.model::<ScenarioInfoManager>().serialize());
        }
        ctx.model::<ScenarioInfoManager>().set(&self.data);
    }

    fn unexecute(&mut self, ctx: &mut Context) {
        if let Some(old) = self.old.clone() {
            ctx.model::<ScenarioInfoManager>().restore(old);
        }
    }
}

register_command!(SetScenarioInfoCommand, "SetScenarioInfoCommand");
