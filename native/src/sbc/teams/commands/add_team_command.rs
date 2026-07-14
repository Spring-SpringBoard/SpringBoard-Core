use serde::Deserialize;

use crate::sbc::command_system::command::Command;
use crate::sbc::command_system::context::Context;
use crate::sbc::command_system::registry::register_command;
use crate::sbc::teams::model::team_manager::{Color, Team, TeamSide};
use crate::sbc::teams::TeamManager;

/// Adds a team. 1:1 with `scen_edit/command/add_team_command.lua`: execute adds
/// the team (recording the assigned id), unexecute removes it.
#[derive(Deserialize, Debug)]
pub struct AddTeamCommand {
    name: Option<String>,
    color: Option<Color>,
    #[serde(rename = "allyTeam")]
    ally_team: Option<i32>,
    side: Option<TeamSide>,
    #[serde(skip)]
    new_team_id: Option<i32>,
}

impl AddTeamCommand {
    /// Construct from a fields payload built by the editor (`name`, `color`,
    /// `allyTeam`, `side`). Transitional: becomes a typed constructor per
    /// docs/porting/todo.md (concrete-commands).
    pub(crate) fn from_fields(fields: serde_json::Value) -> Option<Self> {
        serde_json::from_value(fields).ok()
    }
}

impl Command for AddTeamCommand {
    fn execute(&mut self, ctx: &mut Context) {
        let team = Team {
            name: self.name.clone().unwrap_or_default(),
            color: self.color.unwrap_or_default(),
            ally_team: self.ally_team.unwrap_or_default(),
            side: self.side.clone().unwrap_or_default(),
            ..Default::default()
        };
        let id = ctx.model::<TeamManager>().add_team(team, None);
        self.new_team_id = Some(id);
    }

    fn unexecute(&mut self, ctx: &mut Context) {
        if let Some(id) = self.new_team_id {
            ctx.model::<TeamManager>().remove_team(id);
        }
    }
}

register_command!(AddTeamCommand, "AddTeamCommand");
