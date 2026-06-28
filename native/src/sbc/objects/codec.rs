//! Converts object wire values to and from their typed representations.
use std::any::Any;
use std::collections::HashMap;

use serde::de::DeserializeOwned;
use serde::Serialize;
use serde_json::{Map, Value};

use crate::sbc::objects::model::field_descriptor::{FieldValueType, ObjectFieldDescriptor};
use crate::sbc::objects::model::object_data::{
    Armored, Blocking, Collision, DefRef, FeatureResources, HarvestStorage, MidAimPos,
    RadiusHeight, RuleValue, UnitCommand, UnitFuel, UnitResources, UnitStates, Vec3,
};
use crate::sbc::objects::model::object_value::{FieldValue, ObjectData};

type Rules = HashMap<String, RuleValue>;

/// JSON → typed field value, keyed by the field's declared type.
pub(crate) fn parse_field(value_type: FieldValueType, json: &Value) -> Option<Box<dyn Any>> {
    match value_type {
        FieldValueType::Vec3 | FieldValueType::Direction => from::<Vec3>(json),
        FieldValueType::Float => from::<f32>(json),
        FieldValueType::Int => from::<i32>(json),
        FieldValueType::Bool => from::<bool>(json),
        FieldValueType::String => from::<String>(json),
        FieldValueType::RulesMap => parse_rules(json),
        FieldValueType::CommandList => from::<Vec<UnitCommand>>(json),
        FieldValueType::Object(shape) => parse_object(shape, json),
    }
}

/// Typed field value → JSON, keyed by the field's declared type.
pub(crate) fn field_to_json(value_type: FieldValueType, value: &dyn Any) -> Option<Value> {
    match value_type {
        FieldValueType::Vec3 | FieldValueType::Direction => into::<Vec3>(value),
        FieldValueType::Float => into::<f32>(value),
        FieldValueType::Int => into::<i32>(value),
        FieldValueType::Bool => into::<bool>(value),
        FieldValueType::String => into::<String>(value),
        FieldValueType::RulesMap => into::<Rules>(value),
        FieldValueType::CommandList => into::<Vec<UnitCommand>>(value),
        FieldValueType::Object(shape) => to_json_object(shape, value),
    }
}

/// Build a typed [`FieldValue`] for `descriptor` from a wire value.
pub(crate) fn parse_named_field(
    descriptor: &ObjectFieldDescriptor,
    json: &Value,
) -> Option<FieldValue> {
    Some(FieldValue {
        name: descriptor.name,
        value_type: descriptor.value_type,
        value: parse_field(descriptor.value_type, json)?,
    })
}

/// Parse a wire `{name: value}` map into typed fields, in descriptor order;
/// keys that are not modeled fields (`defName`, `__modelID`, unknowns) are
/// skipped. Also reads the def reference and stable modelID if present.
pub(crate) fn json_to_object(descriptors: &[ObjectFieldDescriptor], params: &Value) -> ObjectData {
    let def = params
        .get("defName")
        .and_then(|value| serde_json::from_value::<DefRef>(value.clone()).ok());
    let model_id = params
        .get("__modelID")
        .and_then(Value::as_i64)
        .map(|id| id as i32);
    let mut fields = Vec::new();
    if let Some(map) = params.as_object() {
        for descriptor in descriptors {
            if let Some(value) = map.get(descriptor.name) {
                if let Some(field) = parse_named_field(descriptor, value) {
                    fields.push(field);
                }
            }
        }
    }
    ObjectData {
        def,
        model_id,
        fields,
    }
}

/// Serialize typed object data to the wire `{defName?, ..fields, __modelID?}`.
pub(crate) fn object_to_json(object: &ObjectData) -> Value {
    let mut map = Map::new();
    if let Some(def) = &object.def {
        if let Ok(value) = serde_json::to_value(def) {
            map.insert("defName".to_owned(), value);
        }
    }
    for field in &object.fields {
        if let Some(value) = field_to_json(field.value_type, &*field.value) {
            map.insert(field.name.to_owned(), value);
        }
    }
    if let Some(model_id) = object.model_id {
        map.insert("__modelID".to_owned(), serde_json::json!(model_id));
    }
    Value::Object(map)
}

fn parse_object(shape: &str, json: &Value) -> Option<Box<dyn Any>> {
    match shape {
        "MidAimPos" => from::<MidAimPos>(json),
        "Blocking" => from::<Blocking>(json),
        "RadiusHeight" => from::<RadiusHeight>(json),
        "Collision" => from::<Collision>(json),
        "FeatureResources" => from::<FeatureResources>(json),
        "UnitFuel" => from::<UnitFuel>(json),
        "HarvestStorage" => from::<HarvestStorage>(json),
        "UnitResources" => from::<UnitResources>(json),
        "Armored" => from::<Armored>(json),
        "UnitStates" => from::<UnitStates>(json),
        other => {
            log::warn!("objects codec: no parser for object type {other:?}");
            None
        }
    }
}

fn to_json_object(shape: &str, value: &dyn Any) -> Option<Value> {
    match shape {
        "MidAimPos" => into::<MidAimPos>(value),
        "Blocking" => into::<Blocking>(value),
        "RadiusHeight" => into::<RadiusHeight>(value),
        "Collision" => into::<Collision>(value),
        "FeatureResources" => into::<FeatureResources>(value),
        "UnitFuel" => into::<UnitFuel>(value),
        "HarvestStorage" => into::<HarvestStorage>(value),
        "UnitResources" => into::<UnitResources>(value),
        "Armored" => into::<Armored>(value),
        "UnitStates" => into::<UnitStates>(value),
        other => {
            log::warn!("objects codec: no serializer for object type {other:?}");
            None
        }
    }
}

/// Rules tolerate Lua's empty-table encoding (`[]`) as "no params".
fn parse_rules(json: &Value) -> Option<Box<dyn Any>> {
    if json.as_array().is_some_and(|items| items.is_empty()) {
        return Some(Box::new(Rules::new()));
    }
    from::<Rules>(json)
}

fn from<T: DeserializeOwned + 'static>(json: &Value) -> Option<Box<dyn Any>> {
    match serde_json::from_value::<T>(json.clone()) {
        Ok(value) => Some(Box::new(value)),
        Err(err) => {
            log::warn!("objects codec: failed to parse value: {err}; payload={json}");
            None
        }
    }
}

fn into<T: Serialize + 'static>(value: &dyn Any) -> Option<Value> {
    serde_json::to_value(value.downcast_ref::<T>()?).ok()
}
