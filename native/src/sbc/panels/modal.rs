//! The shared-modal concept: a small trait every app-wide dialog implements,
//! and an inventory registry that collects them. `ModalStack` drives whatever
//! is registered without naming any concrete dialog, so a new dialog is added
//! by submitting a `ModalRegistration` from its own module -- nothing in the
//! shell changes, exactly as editors register themselves (see `registry.rs`).

use std::any::Any;

use spring_native::prelude::{Error, NativeInterfaceRef};

use crate::sbc::command_system::command::Command;
use crate::sbc::panels::editor::Editor;
use crate::sbc::panels::field::{ChangeQueue, FieldValue, InteractionQueue};

/// What a modal produced this tick, in the order it must be applied.
pub(crate) enum ModalEvent {
    /// Write a value into the active editor's field and dispatch its command;
    /// `preview` keeps it off the undo history.
    FieldValue {
        field: String,
        value: FieldValue,
        preview: bool,
    },
    Commands(Vec<Box<dyn Command>>),
}

/// A modal dialog the stack drives uniformly. `open` is deliberately absent:
/// its arguments differ per dialog and the caller opening one always knows the
/// concrete type (a colour field opens the colour picker), so opening goes
/// through `ModalStack::get_mut::<T>()` while everything the stack has to do
/// blind -- bind, close, poll -- lives here.
pub(crate) trait Modal: Any {
    /// The static shell injected into `#modal-root` once, before any binding.
    fn markup(&self) -> String;

    fn bind(
        &mut self,
        interface: &NativeInterfaceRef,
        document: u64,
        changes: &ChangeQueue,
        interactions: &InteractionQueue,
    ) -> Result<(), Error>;

    /// A fresh RmlUi context: every cached element handle is stale.
    fn forget_bindings(&mut self);

    fn is_open(&self) -> bool;

    /// Close if open (the Escape path). Returns whether it was open.
    fn cancel_if_open(
        &mut self,
        interface: &NativeInterfaceRef,
        document: u64,
    ) -> Result<bool, Error>;

    /// Advance one tick and report what it produced.
    fn poll(
        &mut self,
        interface: &NativeInterfaceRef,
        document: u64,
    ) -> Result<Vec<ModalEvent>, Error>;

    /// The modal's field surface while it is open, for drag/edit routing. A
    /// dialog without form fields (the colour and asset pickers) leaves the
    /// default.
    fn field_editor(&self) -> Option<&dyn Editor> {
        None
    }
    fn field_editor_mut(&mut self) -> Option<&mut dyn Editor> {
        None
    }

    fn as_any_mut(&mut self) -> &mut dyn Any;
}

/// One registered modal. Adding a dialog means submitting one of these from its
/// own module; the stack collects them and orders them by `order`, which is the
/// Escape/poll priority (lowest first).
pub(crate) struct ModalRegistration {
    pub order: u32,
    pub make: fn() -> Box<dyn Modal>,
}

inventory::collect!(ModalRegistration);

/// Every registered modal's markup, concatenated in registration order. Built
/// from throwaway instances so the view can inject it without owning the stack,
/// matching how each dialog's markup was a plain default-instance call before.
pub(crate) fn registered_markup() -> String {
    let mut specs: Vec<&ModalRegistration> =
        inventory::iter::<ModalRegistration>.into_iter().collect();
    specs.sort_by_key(|reg| reg.order);
    specs.iter().map(|reg| (reg.make)().markup()).collect()
}
