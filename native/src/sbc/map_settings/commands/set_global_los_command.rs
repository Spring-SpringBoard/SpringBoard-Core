use log::debug;
use serde::Deserialize;

use crate::sbc::command_system::command::Command;
use crate::sbc::command_system::context::Context;
use crate::sbc::command_system::registry::register_command;

/// Sets global LOS for an ally-team. 1:1 with
/// `scen_edit/command/set_global_los_command.lua` (`Spring.SetGlobalLos`). No
/// undo — the Lua command defines no `unexecute`.
#[derive(Deserialize, Debug)]
pub struct SetGlobalLosCommand {
    opts: Opts,
}

#[derive(Deserialize, Debug)]
struct Opts {
    #[serde(rename = "allyTeamID")]
    ally_team_id: i32,
    value: bool,
}

impl Command for SetGlobalLosCommand {
    fn execute(&mut self, ctx: &mut Context) {
        debug!(
            "SetGlobalLosCommand: allyTeam {} = {}",
            self.opts.ally_team_id, self.opts.value
        );
        let _ = ctx
            .interface
            .synced_ctrl()
            .team()
            .set_global_los(self.opts.ally_team_id, self.opts.value);
    }

    fn undoable(&self) -> bool {
        false
    }
}

register_command!(SetGlobalLosCommand, "SetGlobalLosCommand");
