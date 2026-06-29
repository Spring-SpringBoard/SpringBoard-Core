use log::debug;
use serde::Deserialize;

use crate::sbc::command_system::command::Command;
use crate::sbc::command_system::context::Context;
use crate::sbc::command_system::registry::register_command;

/// Reassigns a player to a team and flips global LOS so the new ally-team is
/// revealed (and the old one hidden). 1:1 with
/// `scen_edit/command/change_player_team_command.lua`. No undo (Lua defines no
/// `unexecute`).
#[derive(Deserialize, Debug)]
pub struct ChangePlayerTeamCommand {
    #[serde(rename = "playerID")]
    player_id: i32,
    #[serde(rename = "teamID")]
    team_id: i32,
}

impl Command for ChangePlayerTeamCommand {
    fn execute(&mut self, ctx: &mut Context) {
        debug!(
            "ChangePlayerTeamCommand: player {} -> team {}",
            self.player_id, self.team_id
        );

        let prev_ally_team = ctx
            .interface
            .teams()
            .get_player_info(self.player_id, false)
            .map(|info| info.allyTeamID)
            .unwrap_or(-1);

        let synced = ctx.interface.synced_ctrl();
        let team_ctrl = synced.team();
        let _ = team_ctrl.assign_player_to_team(self.player_id, self.team_id);
        if prev_ally_team >= 0 {
            let _ = team_ctrl.set_global_los(prev_ally_team, false);
        }

        let new_ally_team = ctx
            .interface
            .teams()
            .get_team_info(self.team_id, false)
            .map(|info| info.allyTeamID)
            .unwrap_or(-1);
        if new_ally_team >= 0 {
            let _ = team_ctrl.set_global_los(new_ally_team, true);
        }
    }

    fn undoable(&self) -> bool {
        false
    }
}

register_command!(ChangePlayerTeamCommand, "ChangePlayerTeamCommand");
