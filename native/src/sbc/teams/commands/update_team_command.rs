use serde::Deserialize;

use crate::sbc::command_system::command::Command;
use crate::sbc::command_system::context::Context;
use crate::sbc::command_system::registry::register_command;
use crate::sbc::teams::model::team_manager::Team;
use crate::sbc::teams::TeamManager;

/// Updates a team. 1:1 with `scen_edit/command/update_team_command.lua`:
/// execute saves the old team then sets the new one; unexecute restores the old.
///
/// The Lua command has an `onlyIfNoTeamColor` path gated on the team manager's
/// `__loaded_from_file` flag (a project-load hack). That flag is owned by the
/// load flow (project slice, not yet ported), so it's omitted here; revisit
/// when the project-load slice lands.
#[derive(Deserialize, Debug)]
pub struct UpdateTeamCommand {
    team: Team,
    #[serde(skip)]
    old: Option<Team>,
}

impl UpdateTeamCommand {
    /// Construct from a serialized `team` payload. Transitional: the team DTO
    /// becomes a typed constructor per docs/porting/todo.md (concrete-commands).
    pub(crate) fn from_team(team: serde_json::Value) -> Option<Self> {
        serde_json::from_value(team)
            .ok()
            .map(|team| Self { team, old: None })
    }
}

impl Command for UpdateTeamCommand {
    fn execute(&mut self, ctx: &mut Context) {
        // Snapshot once: redo re-runs this same instance, so re-capturing here
        // would store the already-updated value (matches Lua's `if not self.old`).
        if self.old.is_none() {
            self.old = ctx.model::<TeamManager>().get_team(self.team.id).cloned();
        }
        ctx.model::<TeamManager>()
            .set_team(self.team.id, self.team.clone());
    }

    fn unexecute(&mut self, ctx: &mut Context) {
        if let Some(old) = self.old.clone() {
            ctx.model::<TeamManager>().set_team(old.id, old);
        }
    }
}

register_command!(UpdateTeamCommand, "UpdateTeamCommand");
