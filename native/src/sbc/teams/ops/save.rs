//! Serializes the team model to JSON for project save.

use serde_json::Value;

use crate::sbc::teams::TeamManager;

/// Serialize teams as `[{ team, id }]`, ordered by id.
pub(crate) fn save(tm: &TeamManager) -> Value {
    Value::Array(
        tm.all_teams()
            .into_iter()
            .map(|team| {
                let id = team.id;
                serde_json::json!({ "team": team, "id": id })
            })
            .collect(),
    )
}
