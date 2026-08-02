//! Runtime lifecycle operations owned by the engine, rather than an editor.

use serde_json::json;

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
