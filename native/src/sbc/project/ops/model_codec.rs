use serde_json::Value;

use super::super::model::scenario_info_manager::{ScenarioInfo, ScenarioInfoManager};
use crate::sbc::command_system::context::Context;
use crate::sbc::objects::{codec, ObjectKind, ObjectManager};
use crate::sbc::sbc::SBC;
use crate::sbc::teams::ops as team;
use crate::sbc::teams::TeamManager;
use crate::sbc::triggers::TriggerManager;
use crate::sbc::variables::VariableManager;

pub fn serialize_model_ctx(ctx: &mut Context) -> Value {
    let triggers = ctx.model::<TriggerManager>().serialize();
    let variables = ctx.model::<VariableManager>().serialize();
    let teams = team::save::save(ctx.model::<TeamManager>());
    let info = ctx.model::<ScenarioInfoManager>().serialize();
    let units = serialize_objects_ctx(ctx, ObjectKind::Unit);
    let features = serialize_objects_ctx(ctx, ObjectKind::Feature);

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
    clear_objects(sbc, ObjectKind::Unit);
    clear_objects(sbc, ObjectKind::Feature);

    if let Some(units) = mission.get("unit") {
        load_objects(sbc, ObjectKind::Unit, units);
    }
    if let Some(features) = mission.get("feature") {
        load_objects(sbc, ObjectKind::Feature, features);
    }

    let Some(meta) = mission.get("meta") else {
        return;
    };
    if let Some(variables) = meta.get("variables") {
        sbc.model::<VariableManager>().load(variables);
    }
    if let Some(teams) = meta.get("teams") {
        team::load::load(sbc.model::<TeamManager>(), teams);
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

fn serialize_objects_ctx(ctx: &mut Context, kind: ObjectKind) -> Vec<Value> {
    let manager = ctx.model::<ObjectManager>();
    let latest_id = manager.latest_model_id(kind);
    (1..=latest_id)
        .filter_map(|model_id| manager.get(kind, model_id))
        .map(|object| codec::object_to_json(&object))
        .collect()
}

fn clear_objects(sbc: &mut SBC, kind: ObjectKind) {
    let latest_id = sbc.model::<ObjectManager>().latest_model_id(kind);
    for model_id in (1..=latest_id).rev() {
        sbc.model::<ObjectManager>().remove(kind, model_id);
    }
}

fn load_objects(sbc: &mut SBC, kind: ObjectKind, objects: &Value) {
    let Some(objects) = objects.as_array() else {
        return;
    };
    let Some(descriptors) = sbc.model::<ObjectManager>().field_descriptors(kind) else {
        return;
    };
    for value in objects {
        let object = codec::json_to_object(&descriptors, value);
        let model_id = object.model_id;
        sbc.model::<ObjectManager>().add(kind, &object, model_id);
    }
}
