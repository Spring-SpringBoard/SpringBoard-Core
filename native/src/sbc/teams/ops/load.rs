//! Loads the team model from saved project JSON.

use serde_json::Value;

use crate::sbc::teams::{Team, TeamManager};

/// Replace the team model with the `[{ team, id }]` array in `data`.
pub(crate) fn load(tm: &mut TeamManager, data: &Value) {
    tm.clear();
    let Some(teams) = data.as_array() else {
        return;
    };
    for kv in teams {
        let Some(team_value) = kv.get("team") else {
            continue;
        };
        let Ok(team) = serde_json::from_value::<Team>(team_value.clone()) else {
            continue;
        };
        let id = kv
            .get("id")
            .and_then(|id| id.as_i64())
            .map(|id| id as i32)
            .unwrap_or(team.id);
        tm.add_team(team, Some(id));
    }
}
