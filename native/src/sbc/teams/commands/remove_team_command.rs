use serde::Deserialize;

use crate::sbc::command_system::command::Command;
use crate::sbc::command_system::context::Context;
use crate::sbc::command_system::registry::register_command;
use crate::sbc::teams::model::team_manager::Team;
use crate::sbc::teams::TeamManager;

/// Removes a team. 1:1 with `scen_edit/command/remove_team_command.lua`:
/// execute saves the team then removes it; unexecute re-adds it with the same id.
#[derive(Deserialize, Debug)]
pub struct RemoveTeamCommand {
    #[serde(rename = "teamID")]
    team_id: i32,
    #[serde(skip)]
    saved: Option<Team>,
}

impl Command for RemoveTeamCommand {
    fn execute(&mut self, ctx: &mut Context) {
        self.saved = ctx.model::<TeamManager>().get_team(self.team_id).cloned();
        ctx.model::<TeamManager>().remove_team(self.team_id);
    }

    fn unexecute(&mut self, ctx: &mut Context) {
        if let Some(team) = self.saved.clone() {
            ctx.model::<TeamManager>()
                .add_team(team, Some(self.team_id));
        }
    }
}

register_command!(RemoveTeamCommand, "RemoveTeamCommand");
