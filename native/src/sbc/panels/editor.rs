use spring_native::prelude::{Error, NativeInterfaceRef};

use crate::sbc::command_system::model::Models;

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

    /// Read current state into field values. `models` gives access to the
    /// project models for views backed by project state rather than the engine
    /// (scenario info, teams).
    fn refresh_from_engine(&mut self, interface: &NativeInterfaceRef, models: &mut Models);

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

    /// The field's colour, if it is a colour field: the manager opens the
    /// picker on it instead of entering edit mode.
    fn field_color(&self, name: &str) -> Option<[f32; 4]>;

    /// Write a colour back into the field and the DOM (picker accepted).
    fn set_field_color(&mut self, name: &str, rgba: [f32; 4], interface: &NativeInterfaceRef);
}
