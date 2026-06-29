use serde_json::Value;

use crate::sbc::objects::model::field_descriptor::{
    FieldRange, FieldValueType, ObjectFieldDescriptor,
};

#[derive(Debug, Clone)]
pub struct FieldMutation {
    pub field: &'static str,
    pub value: Value,
}

pub fn values_for_descriptors(
    descriptors: &[ObjectFieldDescriptor],
    current: &serde_json::Map<String, Value>,
    seed: u64,
) -> Vec<FieldMutation> {
    descriptors
        .iter()
        .filter_map(|descriptor| {
            let current_value = current.get(descriptor.name)?;
            if descriptor.name == "health"
                || descriptor.name == "midAimPos"
                || descriptor.name == "team"
            {
                return None;
            }
            Some(FieldMutation {
                field: descriptor.name,
                value: value_for_descriptor(descriptor, Some(current_value), seed),
            })
        })
        .collect()
}

fn value_for_descriptor(
    descriptor: &ObjectFieldDescriptor,
    current: Option<&Value>,
    seed: u64,
) -> Value {
    let n = (seed % 997) as f64;
    match descriptor.value_type {
        FieldValueType::Bool => {
            serde_json::json!(!current.and_then(Value::as_bool).unwrap_or(false))
        }
        FieldValueType::CommandList => serde_json::json!([]),
        FieldValueType::Direction => serde_json::json!({ "x": 0.0, "y": 0.0, "z": 1.0 }),
        FieldValueType::Float => serde_json::json!(number_in_range(
            current.and_then(Value::as_f64),
            descriptor.range,
            0.25 + n
        )),
        FieldValueType::Int => serde_json::json!(number_in_range(
            current.and_then(Value::as_f64),
            descriptor.range,
            1.0 + n
        ) as i32),
        FieldValueType::Object(shape) => object_value(shape, current, descriptor.range, seed),
        FieldValueType::RulesMap => serde_json::json!({
            "native_set_param_number": seed as f64,
            "native_set_param_flag": seed.is_multiple_of(2),
            "native_set_param_label": format!("case-{seed}")
        }),
        FieldValueType::String => serde_json::json!(format!("native-set-param-{seed}")),
        FieldValueType::Vec3 if descriptor.name == "rot" => {
            vec3_offset(current, 0.1 + n % 3.0 * 0.01, 0.2 + n % 5.0 * 0.01, 0.3)
        }
        FieldValueType::Vec3 => vec3_offset(current, 7.0 + n % 11.0, 3.0, 5.0 + n % 13.0),
    }
}

fn object_value(
    shape: &str,
    current: Option<&Value>,
    range: Option<FieldRange>,
    seed: u64,
) -> Value {
    let n = (seed % 997) as f64;
    match shape {
        "Armored" => serde_json::json!({
            "armored": !current.and_then(|v| v.get("armored")).and_then(Value::as_bool).unwrap_or(false),
            "armorMultiple": number_in_range(child_number(current, "armorMultiple"), range, 0.75)
        }),
        "Blocking" => blocking(current, seed),
        "Collision" => collision(current, seed),
        "FeatureResources" => serde_json::json!({
            "metal": number_in_range(child_number(current, "metal"), range, 3.0),
            "energy": number_in_range(child_number(current, "energy"), range, 4.0),
            "metalMax": positive_child(current, "metalMax", 8.0) + 1.0,
            "energyMax": positive_child(current, "energyMax", 9.0) + 1.0,
            "reclaimLeft": number_in_range(child_number(current, "reclaimLeft"), range, 0.5),
            "reclaimTime": positive_child(current, "reclaimTime", 2.0) + 1.0
        }),
        "HarvestStorage" => serde_json::json!({
            "storedMetal": number_in_range(child_number(current, "storedMetal"), range, 2.0),
            "maxStoredMetal": positive_child(current, "maxStoredMetal", 10.0) + 1.0,
            "storedEnergy": number_in_range(child_number(current, "storedEnergy"), range, 3.0),
            "maxStoredEnergy": positive_child(current, "maxStoredEnergy", 12.0) + 1.0
        }),
        "MidAimPos" => serde_json::json!({
            "mid": { "x": 1.0 + n % 3.0, "y": 8.0 + n % 5.0, "z": 2.0 },
            "aim": { "x": 2.0, "y": 11.0 + n % 7.0, "z": 3.0 + n % 4.0 }
        }),
        "RadiusHeight" => serde_json::json!({
            "radius": positive_child(current, "radius", 8.0) + 2.0 + n % 5.0,
            "height": positive_child(current, "height", 16.0) + 3.0 + n % 7.0
        }),
        "UnitFuel" => serde_json::json!({
            "fuel": number_in_range(child_number(current, "fuel"), range, 5.0 + n % 10.0),
            "maxFuel": positive_child(current, "maxFuel", 20.0) + n % 10.0
        }),
        "UnitResources" => serde_json::json!({
            "metalMake": number_in_range(child_number(current, "metalMake"), range, 1.0),
            "metalUse": number_in_range(child_number(current, "metalUse"), range, 0.25),
            "energyMake": number_in_range(child_number(current, "energyMake"), range, 2.0),
            "energyUse": number_in_range(child_number(current, "energyUse"), range, 0.5)
        }),
        "UnitStates" => serde_json::json!({
            "fireState": 1,
            "moveState": 1,
            "autoRepairLevel": 0.0,
            "repeat": true,
            "cloak": false,
            "active": true,
            "trajectory": false,
            "autoLand": true,
            "loopbackAttack": false
        }),
        _ => serde_json::json!({}),
    }
}

fn number_in_range(current: Option<f64>, range: Option<FieldRange>, fallback: f64) -> f64 {
    let mut value = current.unwrap_or(fallback) + fallback.abs().max(1.0);
    if let Some(min) = range.and_then(|r| r.min) {
        value = value.max(min);
    }
    if let Some(max) = range.and_then(|r| r.max) {
        value = value.min(max);
    }
    value
}

fn vec3_offset(current: Option<&Value>, dx: f64, dy: f64, dz: f64) -> Value {
    serde_json::json!({
        "x": child_number(current, "x").unwrap_or(64.0) + dx,
        "y": child_number(current, "y").unwrap_or(24.0) + dy,
        "z": child_number(current, "z").unwrap_or(64.0) + dz
    })
}

fn blocking(current: Option<&Value>, seed: u64) -> Value {
    let flip = |key| {
        !current
            .and_then(|v| v.get(key))
            .and_then(Value::as_bool)
            .unwrap_or(false)
    };
    serde_json::json!({
        "isBlocking": flip("isBlocking"),
        "isSolidObjectCollidable": true,
        "isProjectileCollidable": !seed.is_multiple_of(3),
        "isRaySegmentCollidable": true,
        "crushable": flip("crushable"),
        "blockEnemyPushing": seed.is_multiple_of(2),
        "blockHeightChanges": seed.is_multiple_of(5)
    })
}

fn collision(current: Option<&Value>, _seed: u64) -> Value {
    serde_json::json!({
        "scaleX": positive_child(current, "scaleX", 8.0),
        "scaleY": positive_child(current, "scaleY", 16.0),
        "scaleZ": positive_child(current, "scaleZ", 8.0),
        "offsetX": child_number(current, "offsetX").unwrap_or(0.0) + 0.5,
        "offsetY": child_number(current, "offsetY").unwrap_or(0.0) + 0.25,
        "offsetZ": child_number(current, "offsetZ").unwrap_or(0.0) + 0.75,
        "vType": child_number(current, "vType").unwrap_or(1.0) as i32,
        "testType": child_number(current, "testType").unwrap_or(1.0) as i32,
        "axis": child_number(current, "axis").unwrap_or(1.0) as i32
    })
}

fn positive_child(current: Option<&Value>, key: &str, default: f64) -> f64 {
    child_number(current, key).unwrap_or(default).max(0.1)
}

fn child_number(current: Option<&Value>, key: &str) -> Option<f64> {
    current?.get(key)?.as_f64()
}
