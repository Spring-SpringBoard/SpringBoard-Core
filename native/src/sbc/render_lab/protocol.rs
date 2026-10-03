//! Command lines sent to the renderer in the native → LuaRules envelope. Format: see the
//! game's `shipcore::lab::wire`.

use spring_native::prelude::NativeInterfaceRef;

use crate::sbc::lua_bridge;
use crate::sbc::panels::field::FieldValue;

pub(crate) const TAG: &str = "renderLab";

pub(crate) fn send(engine: &NativeInterfaceRef, line: &str) {
    lua_bridge::rules_message(engine, TAG, serde_json::Value::String(line.to_string()));
}

pub(crate) fn list(engine: &NativeInterfaceRef) {
    send(engine, "list");
}

pub(crate) fn set(engine: &NativeInterfaceRef, id: &str, value: &FieldValue) {
    let word = match value {
        FieldValue::Bool(on) => u8::from(*on).to_string(),
        FieldValue::Number(n) => n.to_string(),
        FieldValue::Text(text) => text.clone(),
        FieldValue::Color(_) => return,
    };
    send(engine, &format!("set {id} {word}"));
}

pub(crate) fn view(engine: &NativeInterfaceRef, id: &str) {
    send(engine, &format!("view {id}"));
}

pub(crate) fn overlay(engine: &NativeInterfaceRef, id: &str, on: bool) {
    send(engine, &format!("overlay {id} {}", u8::from(on)));
}

pub(crate) fn solo(engine: &NativeInterfaceRef, id: Option<&str>) {
    send(engine, &format!("solo {}", id.unwrap_or("off")));
}

/// Back to the starting values: one panel's controls, or (`None`) every control.
pub(crate) fn reset(engine: &NativeInterfaceRef, panel: Option<&str>) {
    match panel {
        Some(panel) => send(engine, &format!("reset {panel}")),
        None => send(engine, "reset"),
    }
}

pub(crate) fn scene(engine: &NativeInterfaceRef, id: &str) {
    send(engine, &format!("scene {id}"));
}
