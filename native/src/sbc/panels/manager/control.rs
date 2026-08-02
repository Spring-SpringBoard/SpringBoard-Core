//! The narrow automation/control channel for opening editors and setting fields.

use super::PanelManager;
use crate::sbc::actions::Action;
use crate::sbc::command_system::model::Models;
use crate::sbc::control::ControlError;
use crate::sbc::panels::field::{FieldSpec, FieldValue};
use crate::sbc::panels::registry::EditorSpec;
use crate::sbc::panels::view::ShellEvent;

impl PanelManager {
    pub(crate) fn control_open_dialog(
        &mut self,
        name: &str,
        models: &mut Models,
    ) -> Result<&'static str, ControlError> {
        let action = Action::from_dialog_name(name).ok_or_else(|| {
            ControlError::unknown(format!(
                "no such dialog: {name}. Call describe for the list."
            ))
        })?;
        let canonical = action
            .dialog_name()
            .expect("dialog names map only to dialog actions");
        self.run_action(action, models)
            .map_err(|err| ControlError::failed(format!("opening dialog {name}: {err:?}")))?;
        Ok(canonical)
    }

    pub(crate) fn control_dialog_is_open(&self, name: &str) -> bool {
        self.modals.control_is_open(name)
    }

    pub(crate) fn control_dialog_field_value(
        &self,
        dialog: &str,
        field: &str,
    ) -> Result<(FieldSpec, String), ControlError> {
        self.modals.control_field_value(dialog, field)
    }

    pub(crate) fn control_set_dialog_field(
        &mut self,
        dialog: &str,
        field: &str,
        value: FieldValue,
    ) -> Result<FieldValue, ControlError> {
        self.modals
            .control_set_field(dialog, field, value, &self.interface)
    }

    pub(crate) fn control_select_dialog(
        &mut self,
        dialog: &str,
        path: &str,
    ) -> Result<(), ControlError> {
        let document = self
            .view
            .document_handle()
            .ok_or_else(|| ControlError::failed("panel document is not ready"))?;
        self.modals
            .control_select(dialog, path, &self.interface, document)
    }

    pub(crate) fn control_accept_dialog(&mut self, dialog: &str) -> Result<(), ControlError> {
        self.modals.control_accept(dialog)
    }

    pub(crate) fn control_cancel_dialog(&mut self, dialog: &str) -> Result<(), ControlError> {
        self.modals.control_cancel(dialog)
    }

    pub(crate) fn control_open(&mut self, spec: &'static EditorSpec) {
        self.view.queue_event(ShellEvent::Tab(spec.tab));
        self.view.queue_event(ShellEvent::Editor(spec.name));
    }

    pub(crate) fn control_open_editor(&self) -> Option<&'static str> {
        self.view.active_editor()
    }

    pub(crate) fn control_set_field(
        &mut self,
        name: &str,
        value: FieldValue,
    ) -> Result<FieldValue, ControlError> {
        let spec = self.control_field_spec(name)?;
        if let (Some(options), FieldValue::Text(text)) = (&spec.options, &value) {
            if !options.contains(text) {
                return Err(ControlError::unknown(format!(
                    "{name} does not accept {text:?}. Its options: {}",
                    options.join(", ")
                )));
            }
        }
        let editor = self
            .slot
            .editor_mut()
            .ok_or_else(|| ControlError::unknown("no editor is open"))?;
        let commands = self
            .session
            .apply_field_value(name, value, false, editor, &self.interface);
        self.pending_commands.extend(commands);
        self.control_field_value(name)
    }

    pub(crate) fn control_field_value(&self, name: &str) -> Result<FieldValue, ControlError> {
        Ok(self.control_field_spec(name)?.value)
    }

    fn control_field_spec(&self, name: &str) -> Result<FieldSpec, ControlError> {
        let editor = self
            .slot
            .editor()
            .ok_or_else(|| ControlError::unknown("no editor is open"))?;
        let specs = editor.field_specs();
        specs
            .iter()
            .find(|spec| spec.name == name)
            .cloned()
            .ok_or_else(|| {
                let open = self.view.active_editor().unwrap_or("<none>");
                let names: Vec<&str> = specs.iter().map(|spec| spec.name.as_str()).collect();
                ControlError::unknown(format!(
                    "no field {name} in {open}. Its fields: {}",
                    names.join(", ")
                ))
            })
    }
}
