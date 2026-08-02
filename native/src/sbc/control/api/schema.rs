//! What the editor offers, answered from the registries themselves: the editor
//! registry, each editor's field model, and the command registry.

use serde_json::{json, Value};

use crate::sbc::command_system::registry::registered_class_names;
use crate::sbc::panels::field::{FieldSpec, FieldValue};
use crate::sbc::panels::registry::{editors_for, Tab};

pub(crate) fn describe() -> Value {
    let tabs: Vec<Value> = Tab::all()
        .into_iter()
        .map(|tab| {
            let editors: Vec<Value> = editors_for(tab)
                .into_iter()
                .map(|spec| {
                    // Building the editor is what gives its field list. Editors
                    // are plain field structs until they are bound to a
                    // document, so this touches nothing.
                    let editor = (spec.make)();
                    json!({
                        "name": spec.name,
                        "caption": spec.caption,
                        "fields": editor.field_specs().into_iter().map(field_json).collect::<Vec<_>>(),
                    })
                })
                .collect();
            json!({ "name": tab.as_str(), "editors": editors })
        })
        .collect();

    json!({
        "tabs": tabs,
        "dialogs": dialog_descriptors(),
        "commands": registered_class_names(),
    })
}

/// The value a field currently holds, in the JSON shape `ui.set` accepts back.
pub(crate) fn value_json(value: &FieldValue) -> Value {
    match value {
        FieldValue::Number(n) => json!(n),
        FieldValue::Color(rgba) => json!(rgba),
        FieldValue::Text(text) => json!(text),
        FieldValue::Bool(b) => json!(b),
    }
}

pub(crate) fn kind_of(value: &FieldValue) -> &'static str {
    match value {
        FieldValue::Number(_) => "number",
        FieldValue::Color(_) => "color",
        FieldValue::Text(_) => "text",
        FieldValue::Bool(_) => "bool",
    }
}

/// Parse a JSON value into the shape the field holds. The field's current value
/// decides the shape, so a wrong type is rejected before anything is applied.
pub(crate) fn parse_value(current: &FieldValue, value: &Value) -> Result<FieldValue, String> {
    match current {
        FieldValue::Number(_) => value
            .as_f64()
            .map(|n| FieldValue::Number(n as f32))
            .ok_or_else(|| format!("expected a number, got {value}")),
        FieldValue::Bool(_) => value
            .as_bool()
            .map(FieldValue::Bool)
            .ok_or_else(|| format!("expected a boolean, got {value}")),
        FieldValue::Text(_) => value
            .as_str()
            .map(|text| FieldValue::Text(text.to_string()))
            .ok_or_else(|| format!("expected a string, got {value}")),
        FieldValue::Color(_) => {
            let channels: Vec<f32> = value
                .as_array()
                .ok_or_else(|| format!("expected [r, g, b, a], got {value}"))?
                .iter()
                .map(|c| c.as_f64().map(|c| c as f32))
                .collect::<Option<Vec<f32>>>()
                .ok_or_else(|| format!("expected numeric colour channels, got {value}"))?;
            match channels.len() {
                3 => Ok(FieldValue::Color([
                    channels[0],
                    channels[1],
                    channels[2],
                    1.0,
                ])),
                4 => Ok(FieldValue::Color([
                    channels[0],
                    channels[1],
                    channels[2],
                    channels[3],
                ])),
                other => Err(format!("expected 3 or 4 colour channels, got {other}")),
            }
        }
    }
}

fn field_json(spec: FieldSpec) -> Value {
    json!({
        "name": spec.name,
        "kind": kind_of(&spec.value),
        "value": value_json(&spec.value),
        "options": spec.options,
    })
}

fn dialog_descriptors() -> Vec<Value> {
    vec![
        json!({
            "name": "new_project",
            "fields": [
                { "name": "name", "kind": "text", "value": "" },
                { "name": "map", "kind": "text", "value": "SB_Blank_Map" },
                { "name": "size_x", "kind": "number", "value": 10.0 },
                { "name": "size_y", "kind": "number", "value": 10.0 },
            ],
        }),
        json!({ "name": "load_project", "fields": [] }),
        json!({
            "name": "save_project_as",
            "fields": [{ "name": "name", "kind": "text", "value": "" }],
        }),
        json!({
            "name": "import",
            "fields": [{ "name": "file_type", "kind": "text", "value": "" }],
        }),
        json!({
            "name": "export",
            "fields": [
                { "name": "name", "kind": "text", "value": "" },
                { "name": "file_type", "kind": "text", "value": "" },
            ],
        }),
    ]
}
