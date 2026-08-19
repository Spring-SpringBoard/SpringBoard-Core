use serde::Deserialize;
use serde_json::json;

use crate::sbc::control::input_counter::InputCounter;
use crate::sbc::sbc::SBC;

use super::super::channel::Effect;
use super::super::{ControlError, Handled, Reply};

pub(crate) fn barrier(sbc: &mut SBC) -> Handled {
    Ok(Reply::When(Effect::InputIdle {
        observed_input: sbc.model::<InputCounter>().epoch(),
        quiet_updates: 0,
    }))
}

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

pub(crate) fn reload_native_modules(sbc: &SBC) -> Handled {
    sbc.interface()
        .messages()
        .send_commands("reloadnativemodules", "")
        .map_err(|error| ControlError::failed(format!("reload native modules: {error:?}")))?;
    Ok(Reply::now(json!({ "reloading": "native-modules" })))
}

#[derive(Deserialize)]
#[serde(tag = "kind")]
pub(crate) enum EmulateInput {
    #[serde(rename = "key_press")]
    KeyPress { keycode: i32 },
    #[serde(rename = "key_release")]
    KeyRelease { keycode: i32 },
    #[serde(rename = "mouse_move")]
    MouseMove { x: i32, y: i32 },
    #[serde(rename = "mouse_press")]
    MousePress { button: i32 },
    #[serde(rename = "mouse_release")]
    MouseRelease { button: i32 },
    #[serde(rename = "mouse_wheel")]
    MouseWheel { delta: f32 },
    #[serde(rename = "text_input")]
    TextInput { text: String },
}

pub(crate) fn emulate_input(sbc: &SBC, input: EmulateInput) -> Handled {
    let debug = sbc.interface().debug_input();
    match input {
        EmulateInput::KeyPress { keycode } => {
            debug
                .emulate_key(keycode, true)
                .map_err(|e| ControlError::failed(format!("key_press: {e:?}")))?;
            Ok(Reply::now(json!({ "kind": "key_press" })))
        }
        EmulateInput::KeyRelease { keycode } => {
            debug
                .emulate_key(keycode, false)
                .map_err(|e| ControlError::failed(format!("key_release: {e:?}")))?;
            Ok(Reply::now(json!({ "kind": "key_release" })))
        }
        EmulateInput::MouseMove { x, y } => {
            debug
                .emulate_mouse_move(x, y)
                .map_err(|e| ControlError::failed(format!("mouse_move: {e:?}")))?;
            Ok(Reply::now(json!({ "kind": "mouse_move" })))
        }
        EmulateInput::MousePress { button } => {
            debug
                .emulate_mouse_button(button, true)
                .map_err(|e| ControlError::failed(format!("mouse_press: {e:?}")))?;
            Ok(Reply::now(json!({ "kind": "mouse_press" })))
        }
        EmulateInput::MouseRelease { button } => {
            debug
                .emulate_mouse_button(button, false)
                .map_err(|e| ControlError::failed(format!("mouse_release: {e:?}")))?;
            Ok(Reply::now(json!({ "kind": "mouse_release" })))
        }
        EmulateInput::MouseWheel { delta } => {
            debug
                .emulate_mouse_wheel(delta)
                .map_err(|e| ControlError::failed(format!("mouse_wheel: {e:?}")))?;
            Ok(Reply::now(json!({ "kind": "mouse_wheel" })))
        }
        EmulateInput::TextInput { ref text } => {
            let consumed = debug
                .emulate_text_input(text)
                .map_err(|e| ControlError::failed(format!("text_input: {e:?}")))?;
            Ok(Reply::now(
                json!({ "kind": "text_input", "consumed": consumed }),
            ))
        }
    }
}
