//! Typed control of dialogs that collect domain input.
//!
//! This is deliberately separate from editor UI control. Domain workflows can
//! open and submit a project/file dialog without synthesising mouse or key
//! events; tests that specifically exercise the dialog's visible controls can
//! continue to use input.

use serde::Deserialize;
use serde_json::{json, Value};

use crate::sbc::actions::Action;
use crate::sbc::panels::PanelManager;
use crate::sbc::sbc::SBC;

use super::super::channel::Effect;
use super::super::{ControlError, Handled, Reply};
use super::schema;

#[derive(Deserialize)]
pub(crate) struct Open {
    pub dialog: String,
}

#[derive(Deserialize)]
pub(crate) struct Field {
    pub dialog: String,
    pub field: String,
}

#[derive(Deserialize)]
pub(crate) struct Dialog {
    pub dialog: String,
}

#[derive(Deserialize)]
pub(crate) struct Set {
    pub dialog: String,
    pub field: String,
    pub value: Value,
}

#[derive(Deserialize)]
pub(crate) struct Select {
    pub dialog: String,
    pub path: String,
}

pub(crate) fn open(sbc: &mut SBC, params: Open) -> Handled {
    let canonical = sbc.models_mut().with::<PanelManager, _>(|panels, models| {
        panels.control_open_dialog(&params.dialog, models)
    })?;
    Ok(Reply::When(Effect::DialogOpen(canonical)))
}

pub(crate) fn get(sbc: &mut SBC, params: Field) -> Handled {
    let (spec, _) = sbc
        .model::<PanelManager>()
        .control_dialog_field_value(&params.dialog, &params.field)?;
    Ok(Reply::now(json!({
        "value": schema::value_json(&spec.value),
        "kind": schema::kind_of(&spec.value),
    })))
}

pub(crate) fn set(sbc: &mut SBC, params: Set) -> Handled {
    let (spec, _) = sbc
        .model::<PanelManager>()
        .control_dialog_field_value(&params.dialog, &params.field)?;
    let value = schema::parse_value(&spec.value, &params.value)
        .map_err(|message| ControlError::invalid(format!("{}: {message}", params.field)))?;
    let applied = sbc.model::<PanelManager>().control_set_dialog_field(
        &params.dialog,
        &params.field,
        value,
    )?;
    Ok(Reply::now(json!({ "value": schema::value_json(&applied) })))
}

pub(crate) fn select(sbc: &mut SBC, params: Select) -> Handled {
    sbc.model::<PanelManager>()
        .control_select_dialog(&params.dialog, &params.path)?;
    Ok(Reply::now(json!({ "path": params.path })))
}

pub(crate) fn accept(sbc: &mut SBC, params: Dialog) -> Handled {
    let canonical = canonical_name(&params.dialog)?;
    sbc.model::<PanelManager>()
        .control_accept_dialog(&params.dialog)?;
    Ok(Reply::When(Effect::DialogClosed(canonical)))
}

pub(crate) fn cancel(sbc: &mut SBC, params: Dialog) -> Handled {
    let canonical = canonical_name(&params.dialog)?;
    sbc.model::<PanelManager>()
        .control_cancel_dialog(&params.dialog)?;
    Ok(Reply::When(Effect::DialogClosed(canonical)))
}

fn canonical_name(name: &str) -> Result<&'static str, ControlError> {
    Action::from_dialog_name(name)
        .and_then(Action::dialog_name)
        .ok_or_else(|| ControlError::unknown(format!("no such dialog: {name}")))
}
