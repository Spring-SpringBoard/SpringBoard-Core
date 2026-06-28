use serde_json::Value;

use super::scenario_info_manager::{ScenarioInfo, ScenarioInfoManager};
use crate::sbc::objects::{ObjectData, ObjectKind, ObjectManager};
use crate::sbc::sbc::SBC;
use crate::sbc::teams::TeamManager;
use crate::sbc::triggers::TriggerManager;
use crate::sbc::variables::VariableManager;

pub fn serialize_model(sbc: &mut SBC) -> Value {
    // Each model is reached one at a time (`model::<T>` hands out a single
    // mutable borrow), so gather each piece before requesting the next.
    let triggers = sbc.model::<TriggerManager>().serialize();
    let variables = sbc.model::<VariableManager>().serialize();
    let teams = sbc.model::<TeamManager>().serialize();
    let info = sbc.model::<ScenarioInfoManager>().serialize();
    let units = sbc.model::<ObjectManager>().serialize_all(ObjectKind::Unit);
    let features = sbc
        .model::<ObjectManager>()
        .serialize_all(ObjectKind::Feature);

    let meta = serde_json::json!({
        "triggers": triggers,
        "variables": variables,
        "teams": teams,
        "info": info,
    });
    serde_json::json!({
        "meta": meta,
        "unit": units,
        "feature": features,
    })
}

pub fn load_model(sbc: &mut SBC, mission: &Value) {
    sbc.model::<ObjectManager>().clear_all();

    if let Some(units) = mission.get("unit") {
        if let Ok(objects) = serde_json::from_value::<Vec<ObjectData>>(units.clone()) {
            sbc.model::<ObjectManager>()
                .load_all(ObjectKind::Unit, &objects);
        }
    }
    if let Some(features) = mission.get("feature") {
        if let Ok(objects) = serde_json::from_value::<Vec<ObjectData>>(features.clone()) {
            sbc.model::<ObjectManager>()
                .load_all(ObjectKind::Feature, &objects);
        }
    }

    let Some(meta) = mission.get("meta") else {
        return;
    };
    if let Some(variables) = meta.get("variables") {
        sbc.model::<VariableManager>().load(variables);
    }
    if let Some(teams) = meta.get("teams") {
        sbc.model::<TeamManager>().load(teams);
    }
    if let Some(info) = meta.get("info") {
        if let Ok(info) = serde_json::from_value::<ScenarioInfo>(info.clone()) {
            sbc.model::<ScenarioInfoManager>().restore(info);
        }
    }
    if let Some(triggers) = meta.get("triggers") {
        sbc.model::<TriggerManager>().load(triggers);
    }
}
