use log::debug;
use serde::Deserialize;

use crate::sbc::command_system::command::Command;
use crate::sbc::command_system::context::Context;
use crate::sbc::command_system::registry::register_command;

/// Sets the alliance state between two ally-teams. 1:1 with
/// `scen_edit/command/set_ally_command.lua` (`Spring.SetAlly`). No undo — the
/// Lua command defines no `unexecute`, so it never lands on the undo stack.
#[derive(Deserialize, Debug)]
pub struct SetAllyCommand {
    #[serde(rename = "firstAllyTeamID")]
    first_ally_team_id: i32,
    #[serde(rename = "secondAllyTeamID")]
    second_ally_team_id: i32,
    ally: bool,
}

impl Command for SetAllyCommand {
    fn execute(&mut self, ctx: &mut Context) {
        debug!(
            "SetAllyCommand: {} <-> {} = {}",
            self.first_ally_team_id, self.second_ally_team_id, self.ally
        );
        let synced = ctx.interface.synced_ctrl();
        let _ =
            synced
                .team()
                .set_ally(self.first_ally_team_id, self.second_ally_team_id, self.ally);
    }

    fn undoable(&self) -> bool {
        false
    }
}

register_command!(SetAllyCommand, "SetAllyCommand");
