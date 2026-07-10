use std::cell::RefCell;
use std::rc::Rc;

use spring_native::prelude::{Error, NativeInterfaceRef};

/// Why a field wants committing. A `blur` that arrives right after an Enter is
/// the input being hidden, not the user leaving the field.
#[derive(Debug, Clone)]
pub struct CommitRequest {
    pub field: String,
    pub from_blur: bool,
}

/// Shared queue of fields asking to be committed. Field event listeners push
/// here; the panel drains it each tick.
pub type ChangeQueue = Rc<RefCell<Vec<CommitRequest>>>;
/// Shared queue of pointer interactions (mousedown/mouseup) for drag support.
pub type InteractionQueue = Rc<RefCell<Vec<InteractionEvent>>>;

pub(crate) fn new_change_queue() -> ChangeQueue {
    Rc::new(RefCell::new(Vec::new()))
}
pub(crate) fn new_interaction_queue() -> InteractionQueue {
    Rc::new(RefCell::new(Vec::new()))
}

#[derive(Debug, Clone)]
pub enum InteractionEvent {
    PointerDown { field: String },
    PointerUp { field: String },
}

#[derive(Debug, Clone)]
pub enum FieldValue {
    Number(f32),
    Color([f32; 4]),
    Text(String),
    Bool(bool),
}

// ── Shared event-registration helpers ──────────────────────────────

/// Register a "change" listener that pushes `name` into the change queue
/// whenever the element's value changes.
pub(crate) fn on_change(
    interface: &NativeInterfaceRef,
    element: u64,
    name: String,
    changes: &ChangeQueue,
) -> Result<(), Error> {
    let cq = changes.clone();
    interface
        .rml_ui()
        .element_add_event_listener(element, "change", false, move || {
            cq.borrow_mut().push(CommitRequest {
                field: name.clone(),
                from_blur: false,
            });
        })?;
    Ok(())
}

/// Register a "blur" listener that asks for the field to be committed when it
/// loses focus. Text inputs fire "change" on every keystroke, so a numeric field
/// must not commit on that: it would dispatch a command per character.
pub(crate) fn on_blur(
    interface: &NativeInterfaceRef,
    element: u64,
    name: String,
    changes: &ChangeQueue,
) -> Result<(), Error> {
    let cq = changes.clone();
    interface
        .rml_ui()
        .element_add_event_listener(element, "blur", false, move || {
            cq.borrow_mut().push(CommitRequest {
                field: name.clone(),
                from_blur: true,
            });
        })?;
    Ok(())
}

/// RmlUi key identifiers (`Rml::Input::KeyIdentifier`).
const KI_NUMPADENTER: i32 = 61;
const KI_RETURN: i32 = 72;

/// Commit a text field when Enter is pressed inside it.
///
/// The engine feeds keyboard input straight to its RmlUi contexts, so a plugin
/// never sees the key through its own `key_press` call-in: the listener has to
/// be on the element. The event's key identifier is read back through
/// `event_get_current`.
pub(crate) fn on_enter(
    interface: &NativeInterfaceRef,
    element: u64,
    name: String,
    changes: &ChangeQueue,
) -> Result<(), Error> {
    let cq = changes.clone();
    let iface = *interface;
    interface
        .rml_ui()
        .element_add_event_listener(element, "keydown", false, move || {
            let rml = iface.rml_ui();
            let Ok((event, ..)) = rml.event_get_current() else {
                return;
            };
            let Ok((key, found)) = rml.event_get_parameter_int(event, "key_identifier") else {
                return;
            };
            if found && (key == KI_RETURN || key == KI_NUMPADENTER) {
                cq.borrow_mut().push(CommitRequest {
                    field: name.clone(),
                    from_blur: false,
                });
            }
        })?;
    Ok(())
}

/// Register mousedown + mouseup listeners for drag support. Pushes
/// `InteractionEvent`s into the interaction queue.
pub(crate) fn on_pointer(
    interface: &NativeInterfaceRef,
    element: u64,
    name: String,
    interactions: &InteractionQueue,
) -> Result<(), Error> {
    let iq = interactions.clone();
    let n = name.clone();
    interface
        .rml_ui()
        .element_add_event_listener(element, "mousedown", false, move || {
            iq.borrow_mut()
                .push(InteractionEvent::PointerDown { field: n.clone() });
        })?;
    let iq2 = interactions.clone();
    let n2 = name.clone();
    interface
        .rml_ui()
        .element_add_event_listener(element, "mouseup", false, move || {
            iq2.borrow_mut()
                .push(InteractionEvent::PointerUp { field: n2.clone() });
        })?;
    Ok(())
}

// ── DOM helpers ────────────────────────────────────────────────────

pub(crate) use crate::sbc::rml::{element_by_id, escape_rml};

/// Format a float for display with a fixed number of decimals.
pub(crate) fn format_number(value: f32, decimals: usize) -> String {
    format!("{:.*}", decimals, value)
}

// ── Field trait ────────────────────────────────────────────────────

/// A single form field. Generates its own RML, binds to the document, and can
/// read/write its value from/to the DOM.
pub trait Field {
    fn name(&self) -> &str;
    fn generate_rml(&self) -> String;
    fn bind(
        &mut self,
        interface: &NativeInterfaceRef,
        document: u64,
        changes: &ChangeQueue,
        interactions: &InteractionQueue,
    ) -> Result<(), Error>;
    fn read_from_dom(&mut self, interface: &NativeInterfaceRef) -> Result<FieldValue, Error>;
    fn write_to_dom(&self, interface: &NativeInterfaceRef) -> Result<(), Error>;
    fn set_value(&mut self, value: &FieldValue);
    fn value(&self) -> FieldValue;

    /// Adjust value while dragging (dx = pixels moved since last tick).
    fn drag(&mut self, _dx: f32, _interface: &NativeInterfaceRef) {}

    /// Finalize a drag. Return the field value for command dispatch.
    fn drag_end(&mut self, _interface: &NativeInterfaceRef) -> Option<FieldValue> {
        None
    }

    /// Set context before a drag (e.g., which color channel "r"/"g"/"b").
    fn prepare_drag(&mut self, _context: &str) {}

    /// The asset root and accepted extensions, for an asset field.
    fn asset_info(&self) -> Option<(String, Vec<String>)> {
        None
    }

    /// True for fields that commit from a text input (Enter or focus loss).
    /// Hiding that input fires a second, stale `blur`, which must not dispatch
    /// Click without drag — enter edit mode.
    fn begin_edit(&mut self, _interface: &NativeInterfaceRef) {}

    /// Click on a sub-component (e.g., color channel) — enter sub-edit.
    fn begin_sub_edit(&mut self, _sub: &str, _interface: &NativeInterfaceRef) {}

    /// Read a sub-component's value from the DOM.
    fn read_sub_field(
        &mut self,
        _sub: &str,
        _interface: &NativeInterfaceRef,
    ) -> Option<FieldValue> {
        None
    }

    /// End edit mode — switch back to display, without committing.
    fn end_edit(&mut self, _interface: &NativeInterfaceRef) {}
}
