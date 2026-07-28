//! Drives whatever modals are registered: binding, Escape order, and polling,
//! so the manager only routes their outcomes. It names no concrete dialog --
//! each registers itself with a `ModalRegistration` (see `modal.rs`). Opening a
//! specific dialog goes through `get_mut::<T>()`, since only the caller knows
//! which one and with what arguments.

use spring_native::prelude::{Error, NativeInterfaceRef};

use crate::sbc::panels::editor::Editor;
use crate::sbc::panels::field::{ChangeQueue, InteractionQueue};
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
}
