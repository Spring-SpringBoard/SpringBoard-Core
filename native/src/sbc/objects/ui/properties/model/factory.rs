//! Field construction and labels for the dynamic properties inspector.

use crate::sbc::objects::{FieldRange, FieldValueType, ObjectFieldDescriptor};
use crate::sbc::panels::field::{Field, FieldValue};
use crate::sbc::panels::fields::{BooleanField, ChoiceField, NumericField, StringField};

use super::{number_f, FIRE_STATES, MOVE_STATES};

pub(super) fn number(value: &serde_json::Value) -> FieldValue {
    FieldValue::Number(number_f(value))
}
pub(super) fn index_of(captions: &[&str], value: &str) -> i32 {
    captions
        .iter()
        .position(|caption| *caption == value)
        .unwrap_or(0) as i32
}

pub(super) fn numeric_field(descriptor: &ObjectFieldDescriptor) -> Box<dyn Field> {
    let mut field = NumericField::new(descriptor.name, title(descriptor.name), 0.0)
        .decimals(if descriptor.value_type == FieldValueType::Int {
            0
        } else {
            2
        })
        .step(if descriptor.value_type == FieldValueType::Int {
            1.0
        } else {
            0.1
        });
    if let Some(FieldRange { min: Some(min), .. }) = descriptor.range {
        field = field.min(min as f32);
    }
    if let Some(FieldRange { max: Some(max), .. }) = descriptor.range {
        field = field.max(max as f32);
    }
    Box::new(field)
}

pub(super) fn sub_field(
    name: &str,
    key: &str,
    value: &serde_json::Value,
) -> Option<Box<dyn Field>> {
    let label = title(key);
    let choices = match key {
        "fireState" => Some(FIRE_STATES),
        "moveState" => Some(MOVE_STATES),
        _ => None,
    };
    if let Some(choices) = choices {
        return Some(Box::new(ChoiceField::new(
            name,
            &label,
            choices.iter().map(|c| (*c).to_string()).collect(),
        )));
    }
    if value.is_boolean() {
        return Some(Box::new(BooleanField::new(name, &label, false)));
    }
    if value.is_number() {
        return Some(Box::new(
            NumericField::new(name, &label, 0.0).decimals(2).compact(),
        ));
    }
    value
        .is_string()
        .then(|| Box::new(StringField::new(name, &label, "")) as Box<dyn Field>)
}

pub(super) fn title(name: &str) -> String {
    let mut out = String::new();
    for (i, ch) in name.chars().enumerate() {
        if i == 0 {
            out.push(ch.to_ascii_uppercase());
        } else if ch.is_ascii_uppercase() {
            out.push(' ');
            out.push(ch);
        } else {
            out.push(ch);
        }
    }
    out
}

pub(super) fn descriptor_order(name: &str) -> usize {
    [
        "defName", "pos", "rot", "dir", "vel", "health", "mass", "maxRange",
    ]
    .iter()
    .position(|candidate| *candidate == name)
    .unwrap_or(usize::MAX)
}
