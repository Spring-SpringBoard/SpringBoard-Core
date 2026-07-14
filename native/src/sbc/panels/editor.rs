use spring_native::prelude::{Error, NativeInterfaceRef};

use crate::sbc::command_system::command::Command;
use crate::sbc::command_system::model::Models;

use crate::sbc::panels::field::{ChangeQueue, FieldValue, InteractionQueue};
use crate::sbc::states::{BrushSettings, StateRequest};

/// An editor panel. Each concrete editor owns its fields, generates its RML
/// body, and processes field changes into typed commands.
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
    ) -> Vec<Box<dyn Command>>;

    /// Process a field change from drag-end: uses the internal value (already
    /// updated during drag). Does NOT read from DOM.
    fn process_drag_end(&mut self, name: &str) -> Vec<Box<dyn Command>>;

    /// Draw-thread work: an editor that renders models to textures (the def
    /// grids' thumbnails) does it here, from `draw_screen`, where GL is current.
    fn draw_thumbnails(&mut self, interface: &NativeInterfaceRef) {
        let _ = interface;
    }

    /// Per-tick work for editors that own something other than fields — a grid
    /// drains its queued clicks here, outside the RmlUi event dispatch.
    fn tick(&mut self, interface: &NativeInterfaceRef, document: u64) -> Vec<Box<dyn Command>> {
        let _ = (interface, document);
        vec![]
    }

    /// The editing state this view wants the editor to enter, if it changed.
    /// Drained by the manager and handed to the `StateManager`.
    fn take_state_request(&mut self) -> Option<StateRequest> {
        None
    }

    /// Clear a brush action when the shared state leaves the editor because of
    /// an external event such as Escape.
    fn clear_state_selection(&mut self, interface: &NativeInterfaceRef, document: u64) {
        let _ = (interface, document);
    }

    /// Whether this editor currently owns a modal rendered outside the panel.
    fn has_open_modal(&self) -> bool {
        false
    }

    /// A cheap per-tick check for views that follow external state (Properties
    /// tracks the selection). Returning true makes the manager refresh and
    /// rebuild this editor. Must be cheap: it runs every tick.
    fn wants_refresh(&mut self, models: &mut Models) -> bool {
        let _ = models;
        false
    }

    /// Whether regenerating the markup (not just the values) is needed on the
    /// next refresh: the Properties view's layout depends on whether anything is
    /// selected.
    fn wants_rebuild(&self) -> bool {
        false
    }

    /// Push field values into the shared brush, so the active state paints with
    /// what the panel shows. Only the Map tab's brush editors do anything here.
    fn write_brush(&self, brush: &mut BrushSettings) {
        let _ = brush;
    }

    /// Take values a state changed (wheel resize, picked height) back into the
    /// fields.
    fn read_brush(&mut self, brush: &BrushSettings, interface: &NativeInterfaceRef) {
        let _ = (brush, interface);
    }

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

    /// The field's current value. The manager decides how to interact with a
    /// field from this: a colour opens the picker, anything else edits inline.
    fn field_value(&self, name: &str) -> FieldValue;

    /// Write a value back into the field and the DOM (picker accepted, asset
    /// picked, a drag restored).
    fn set_field_value(&mut self, name: &str, value: FieldValue, interface: &NativeInterfaceRef);

    /// The field's asset root and accepted extensions, if it is an asset field:
    /// the manager opens the asset picker on it.
    fn field_asset(&self, name: &str) -> Option<(String, Vec<String>)>;
}
