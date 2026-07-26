//! `ui.*`: open an editor, read and write its fields — the same seams a click
//! and an accepted picker value go through.

use serde::Deserialize;
use serde_json::{json, Value};

use crate::sbc::panels::registry::editor_by_name;
use crate::sbc::panels::PanelManager;
use crate::sbc::sbc::SBC;

use super::super::channel::Effect;
use super::super::{ControlError, Handled, Reply};
use super::schema;

#[derive(Deserialize)]
pub(crate) struct Open {
    pub editor: String,
}

#[derive(Deserialize)]
pub(crate) struct Get {
    pub field: String,
}

#[derive(Deserialize)]
pub(crate) struct Set {
    pub field: String,
    pub value: Value,
}

pub(crate) fn open(sbc: &mut SBC, params: Open) -> Handled {
    let spec = editor_by_name(&params.editor).ok_or_else(|| {
        ControlError::unknown(format!(
            "no such editor: {}. Call describe for the list.",
            params.editor
        ))
    })?;
    sbc.model::<PanelManager>().control_open(spec);
    Ok(Reply::When(Effect::EditorOpen(spec.name)))
}

pub(crate) fn set(sbc: &mut SBC, params: Set) -> Handled {
    let panels = sbc.model::<PanelManager>();
    let current = panels.control_field_value(&params.field)?;
    let value = schema::parse_value(&current, &params.value)
        .map_err(|message| ControlError::invalid(format!("{}: {message}", params.field)))?;
    let applied = panels.control_set_field(&params.field, value)?;
    Ok(Reply::now(json!({ "value": schema::value_json(&applied) })))
}

pub(crate) fn get(sbc: &mut SBC, params: Get) -> Handled {
    let value = sbc
        .model::<PanelManager>()
        .control_field_value(&params.field)?;
    Ok(Reply::now(
        json!({ "value": schema::value_json(&value), "kind": schema::kind_of(&value) }),
    ))
}

/// Whether the editor `ui.open` asked for is the one on screen.
pub(crate) fn is_open(sbc: &mut SBC, editor: &str) -> bool {
    sbc.model::<PanelManager>().control_open_editor() == Some(editor)
}
