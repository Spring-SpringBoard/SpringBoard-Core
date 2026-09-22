//! Runtime lifecycle operations owned by the engine, rather than an editor.

use serde_json::{json, Value};

use crate::sbc::sbc::SBC;

use super::super::channel::Effect;
use super::super::{ControlError, Handled, Reply};

/// Resolve after input has gone idle for two native updates.
pub(crate) fn barrier(sbc: &SBC) -> Handled {
    Ok(Reply::When(Effect::InputIdle {
        observed_input: sbc.input_epoch(),
        quiet_updates: 0,
    }))
}

/// Recreate native modules without changing the project or engine world.
pub(crate) fn reload_native_modules(sbc: &SBC) -> Handled {
    sbc.interface()
        .messages()
        .send_commands("reloadnativemodules", "")
        .map_err(|error| ControlError::failed(format!("reload native modules: {error:?}")))?;
    Ok(Reply::now(json!({ "reloading": "native-modules" })))
}

/// Undo native history, then recreate native modules.
pub(crate) fn reset_session(sbc: &mut SBC) -> Handled {
    sbc.interface()
        .debug_input()
        .clear_emulated_input(true)
        .map_err(|error| ControlError::failed(format!("clear emulated input: {error:?}")))?;
    let undone = sbc.undo_all().map_err(ControlError::failed)?;
    sbc.interface()
        .messages()
        .send_commands("reloadnativemodules", "")
        .map_err(|error| ControlError::failed(format!("reload native modules: {error:?}")))?;
    Ok(Reply::now(json!({
        "undone": undone,
        "reloading": "native-modules",
    })))
}

/// Select `units` (default: every unit of the local team) and give them one order, as a player's
/// click does: the engine's `GiveOrder` on the selection, sent over the network like any order.
pub(crate) fn give_order(sbc: &SBC, params: Value) -> Handled {
    let interface = sbc.interface();
    let cmd = integer(&params, "cmd")?;
    let values: Vec<f32> = params
        .get("params")
        .and_then(Value::as_array)
        .map(|list| list.iter().filter_map(Value::as_f64).map(|v| v as f32).collect())
        .unwrap_or_default();
    let units: Vec<i32> = match params.get("units").and_then(Value::as_array) {
        Some(list) => list.iter().filter_map(Value::as_i64).map(|id| id as i32).collect(),
        None => {
            let team = interface
                .player()
                .get_local_team_id()
                .map_err(|error| ControlError::failed(format!("local team: {error:?}")))?;
            interface
                .units_query()
                .get_team_units(team)
                .map_err(|error| ControlError::failed(format!("team units: {error:?}")))?
        }
    };
    interface
        .selection()
        .select_unit_array(&units, false)
        .map_err(|error| ControlError::failed(format!("select: {error:?}")))?;
    let given = interface
        .units_commands()
        .give_order(cmd, &values, 0, 0)
        .map_err(|error| ControlError::failed(format!("give order: {error:?}")))?;
    Ok(Reply::now(json!({ "units": units, "given": given })))
}

/// Drive the engine's debug input emulation from the E2E harness.
pub(crate) fn emulate_input(sbc: &SBC, params: Value) -> Handled {
    let kind = params
        .get("kind")
        .and_then(Value::as_str)
        .ok_or_else(|| ControlError::invalid("runtime.emulate_input needs a string kind"))?;

    let debug = sbc.interface().debug_input();
    match kind {
        "key_press" | "key_release" => {
            let key_code = integer(&params, "keycode")?;
            debug
                .emulate_key(key_code, kind == "key_press")
                .map_err(|error| ControlError::failed(format!("debug input {kind}: {error:?}")))?;
        }
        "mouse_move" => {
            let x = integer(&params, "x")?;
            let y = integer(&params, "y")?;
            debug
                .emulate_mouse_move(x, y)
                .map_err(|error| ControlError::failed(format!("debug input {kind}: {error:?}")))?;
        }
        "mouse_press" | "mouse_release" => {
            let button = integer(&params, "button")?;
            debug
                .emulate_mouse_button(button, kind == "mouse_press")
                .map_err(|error| ControlError::failed(format!("debug input {kind}: {error:?}")))?;
        }
        "mouse_wheel" => {
            let delta = number(&params, "delta")?;
            debug
                .emulate_mouse_wheel(delta)
                .map_err(|error| ControlError::failed(format!("debug input {kind}: {error:?}")))?;
        }
        "text_input" => {
            let text = params.get("text").and_then(Value::as_str).ok_or_else(|| {
                ControlError::invalid("runtime.emulate_input requires string \"text\"")
            })?;
            let consumed = debug
                .emulate_text_input(text)
                .map_err(|error| ControlError::failed(format!("debug input {kind}: {error:?}")))?;
            return Ok(Reply::now(json!({
                "kind": kind,
                "consumed": consumed,
            })));
        }
        other => {
            return Err(ControlError::invalid(format!(
                "runtime.emulate_input does not support {other:?}"
            )));
        }
    }

    Ok(Reply::now(json!({ "kind": kind })))
}

fn integer(data: &Value, name: &str) -> Result<i32, ControlError> {
    data.get(name)
        .and_then(Value::as_i64)
        .and_then(|value| i32::try_from(value).ok())
        .ok_or_else(|| {
            ControlError::invalid(format!("runtime.emulate_input requires integer {name:?}"))
        })
}

fn number(data: &Value, name: &str) -> Result<f32, ControlError> {
    data.get(name)
        .and_then(Value::as_f64)
        .filter(|value| value.is_finite())
        .map(|value| value as f32)
        .filter(|value| value.is_finite())
        .ok_or_else(|| {
            ControlError::invalid(format!(
                "runtime.emulate_input requires finite number {name:?}"
            ))
        })
}
