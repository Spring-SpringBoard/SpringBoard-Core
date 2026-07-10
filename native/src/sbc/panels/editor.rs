use spring_native::prelude::{Error, NativeInterfaceRef};

use crate::sbc::panels::field::{ChangeQueue, InteractionQueue};

/// An editor panel. Each concrete editor owns its fields, generates its RML
/// body, and processes field changes into command envelopes.
pub(crate) trait Editor {
    /// Generate the full RML body for this editor (field rows, section headers).
    fn generate_rml(&self) -> String;

    /// Bind all fields to the document (find elements, register event listeners).
    fn bind_fields(
        &mut self,
        interface: &NativeInterfaceRef,
        document: u64,
        changes: &ChangeQueue,
        interactions: &InteractionQueue,
    ) -> Result<(), Error>;

    /// Push all current field values to the DOM.
    fn write_field_values(&self, interface: &NativeInterfaceRef) -> Result<(), Error>;

    /// Process a field change from edit-mode commit: reads the DOM value.
    fn process_change(
        &mut self,
        name: &str,
        interface: &NativeInterfaceRef,
        next_cmd_id: &mut u64,
    ) -> Vec<String>;

    /// Process a field change from drag-end: uses the internal value (already
    /// updated during drag). Does NOT read from DOM.
    fn process_drag_end(&mut self, name: &str, next_cmd_id: &mut u64) -> Vec<String>;

    /// Read engine state into field values.
    fn refresh_from_engine(&mut self, interface: &NativeInterfaceRef);

    /// Find a field by name and drag it. Returns true if the field exists.
    fn drag_field(&mut self, name: &str, dx: f32, interface: &NativeInterfaceRef) -> bool;

    /// Find a field by name and finalize a drag. Returns true if the field existed.
    fn drag_end_field(&mut self, name: &str, interface: &NativeInterfaceRef) -> bool;

    /// Find a field by name and begin edit mode (click without drag).
    fn begin_edit_field(&mut self, name: &str, interface: &NativeInterfaceRef);

    /// Leave edit mode without committing (Escape).
    fn cancel_edit_field(&mut self, name: &str, interface: &NativeInterfaceRef);

    /// Whether the field commits from a text input, so a stale `blur` after the
    /// value was already committed can be ignored.
    fn field_is_text_edit(&self, name: &str) -> bool;
}
