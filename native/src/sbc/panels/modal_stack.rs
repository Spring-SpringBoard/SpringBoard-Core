//! Drives whatever modals are registered: binding, Escape order, and polling,
//! so the manager only routes their outcomes. It names no concrete dialog --
//! each registers itself with a `ModalRegistration` (see `modal.rs`). Opening a
//! specific dialog goes through `get_mut::<T>()`, since only the caller knows
//! which one and with what arguments.

use spring_native::prelude::{Error, NativeInterfaceRef};

use crate::sbc::control::ControlError;
use crate::sbc::panels::editor::Editor;
use crate::sbc::panels::field::{ChangeQueue, FieldSpec, FieldValue, InteractionQueue};
use crate::sbc::panels::modal::{Modal, ModalEvent, ModalRegistration};

pub(crate) struct ModalStack {
    modals: Vec<Box<dyn Modal>>,
}

impl Default for ModalStack {
    fn default() -> Self {
        let mut specs: Vec<&ModalRegistration> =
            inventory::iter::<ModalRegistration>.into_iter().collect();
        specs.sort_by_key(|reg| reg.order);
        ModalStack {
            modals: specs.iter().map(|reg| (reg.make)()).collect(),
        }
    }
}

impl ModalStack {
    pub(crate) fn control_is_open(&self, name: &str) -> bool {
        self.modal(name).is_some_and(Modal::is_open)
    }

    pub(crate) fn control_field_value(
        &self,
        dialog: &str,
        field: &str,
    ) -> Result<(FieldSpec, String), ControlError> {
        let modal = self
            .modal(dialog)
            .ok_or_else(|| ControlError::unknown(format!("no such dialog: {dialog}")))?;
        if !modal.is_open() {
            return Err(ControlError::failed(format!("dialog {dialog} is not open")));
        }
        let internal = modal
            .control_field_name(field)
            .ok_or_else(|| ControlError::unknown(format!("no field {field} in dialog {dialog}")))?;
        let editor = modal.field_editor().ok_or_else(|| {
            ControlError::failed(format!("dialog {dialog} has no controllable fields"))
        })?;
        let spec = editor
            .field_specs()
            .into_iter()
            .find(|spec| spec.name == internal)
            .ok_or_else(|| ControlError::unknown(format!("no field {field} in dialog {dialog}")))?;
        Ok((spec, internal))
    }

    pub(crate) fn control_set_field(
        &mut self,
        dialog: &str,
        field: &str,
        value: FieldValue,
        interface: &NativeInterfaceRef,
    ) -> Result<FieldValue, ControlError> {
        let modal = self
            .modal_mut(dialog)
            .ok_or_else(|| ControlError::unknown(format!("no such dialog: {dialog}")))?;
        if !modal.is_open() {
            return Err(ControlError::failed(format!("dialog {dialog} is not open")));
        }
        let internal = modal
            .control_field_name(field)
            .ok_or_else(|| ControlError::unknown(format!("no field {field} in dialog {dialog}")))?;
        let editor = modal.field_editor_mut().ok_or_else(|| {
            ControlError::failed(format!("dialog {dialog} has no controllable fields"))
        })?;
        editor.set_field_value(&internal, value, interface);
        Ok(editor.field_value(&internal))
    }

    pub(crate) fn control_select(
        &mut self,
        dialog: &str,
        path: &str,
        interface: &NativeInterfaceRef,
        document: u64,
    ) -> Result<(), ControlError> {
        let modal = self
            .modal_mut(dialog)
            .ok_or_else(|| ControlError::unknown(format!("no such dialog: {dialog}")))?;
        if !modal.is_open() {
            return Err(ControlError::failed(format!("dialog {dialog} is not open")));
        }
        if modal
            .control_select(path, interface, document)
            .map_err(|err| ControlError::failed(format!("selecting {path}: {err:?}")))?
        {
            Ok(())
        } else {
            Err(ControlError::unknown(format!(
                "dialog {dialog} has no selectable item {path:?}"
            )))
        }
    }

    pub(crate) fn control_accept(&mut self, dialog: &str) -> Result<(), ControlError> {
        let modal = self
            .modal_mut(dialog)
            .ok_or_else(|| ControlError::unknown(format!("no such dialog: {dialog}")))?;
        if !modal.is_open() {
            return Err(ControlError::failed(format!("dialog {dialog} is not open")));
        }
        if modal.control_accept() {
            Ok(())
        } else {
            Err(ControlError::failed(format!(
                "dialog {dialog} does not support accept"
            )))
        }
    }

    pub(crate) fn control_cancel(&mut self, dialog: &str) -> Result<(), ControlError> {
        let modal = self
            .modal_mut(dialog)
            .ok_or_else(|| ControlError::unknown(format!("no such dialog: {dialog}")))?;
        if !modal.is_open() {
            return Err(ControlError::failed(format!("dialog {dialog} is not open")));
        }
        if modal.control_cancel() {
            Ok(())
        } else {
            Err(ControlError::failed(format!(
                "dialog {dialog} does not support cancel"
            )))
        }
    }

    /// Set up every modal's data model before their markup enters the document.
    /// `data-for` is structural in RmlUi: binding after parsing is too late.
    pub(crate) fn prepare_data_models(
        &mut self,
        interface: &NativeInterfaceRef,
        context: u64,
    ) -> Result<(), Error> {
        for modal in &mut self.modals {
            modal.prepare_data_model(interface, context)?;
        }
        Ok(())
    }

    /// All registered modal shells in their common stack order.
    pub(crate) fn markup(&self) -> String {
        self.modals.iter().map(|modal| modal.markup()).collect()
    }

    pub(crate) fn bind(
        &mut self,
        interface: &NativeInterfaceRef,
        doc: u64,
        changes: &ChangeQueue,
        interactions: &InteractionQueue,
    ) -> Result<(), Error> {
        for modal in &mut self.modals {
            modal.bind(interface, doc, changes, interactions)?;
        }
        Ok(())
    }

    pub(crate) fn forget_bindings(&mut self) {
        for modal in &mut self.modals {
            modal.forget_bindings();
        }
    }

    pub(crate) fn any_open(&self) -> bool {
        self.modals.iter().any(|modal| modal.is_open())
    }

    pub(crate) fn field_editor(&self) -> Option<&dyn Editor> {
        self.modals.iter().find_map(|modal| modal.field_editor())
    }

    pub(crate) fn field_editor_mut(&mut self) -> Option<&mut dyn Editor> {
        self.modals
            .iter_mut()
            .find_map(|modal| modal.field_editor_mut())
    }

    /// Close the topmost open modal (Escape), in registration order. Returns
    /// whether one was open.
    pub(crate) fn close_top(
        &mut self,
        interface: &NativeInterfaceRef,
        doc: u64,
    ) -> Result<bool, Error> {
        for modal in &mut self.modals {
            if modal.cancel_if_open(interface, doc)? {
                return Ok(true);
            }
        }
        Ok(false)
    }

    /// Advance every modal one tick and collect what they produced.
    pub(crate) fn poll(
        &mut self,
        interface: &NativeInterfaceRef,
        doc: u64,
    ) -> Result<Vec<ModalEvent>, Error> {
        let mut events = Vec::new();
        for modal in &mut self.modals {
            events.extend(modal.poll(interface, doc)?);
        }
        Ok(events)
    }

    /// The registered modal of concrete type `T`, to open it. Panics if none
    /// was registered -- a caller reaching for a specific dialog requires it.
    pub(crate) fn get_mut<T: Modal>(&mut self) -> &mut T {
        self.modals
            .iter_mut()
            .find_map(|modal| modal.as_any_mut().downcast_mut::<T>())
            .expect("modal not registered")
    }

    fn modal(&self, name: &str) -> Option<&dyn Modal> {
        self.modals
            .iter()
            .find(|modal| modal.control_name() == Some(name))
            .map(|modal| &**modal)
    }

    fn modal_mut(&mut self, name: &str) -> Option<&mut dyn Modal> {
        self.modals
            .iter_mut()
            .find(|modal| modal.control_name() == Some(name))
            .map(|modal| &mut **modal)
    }
}
