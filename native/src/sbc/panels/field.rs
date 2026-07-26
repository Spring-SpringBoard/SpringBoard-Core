use std::cell::RefCell;
use std::rc::Rc;

use spring_native::prelude::{Error, NativeInterfaceRef};

/// Why a field wants committing. A `blur` that arrives right after an Enter is
/// the input being hidden, not the user leaving the field.
#[derive(Debug, Clone)]
pub struct CommitRequest {
    pub field: String,
    pub from_blur: bool,
    /// Escape: throw the edit away and put the held value back on screen. The
    /// blur that follows must not then commit what is still typed in the box.
    pub revert: bool,
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
    PointerDown {
        field: String,
    },
    PointerUp {
        field: String,
    },
    /// RmlUi's drag, which captures the pointer: `DragEnd` arrives wherever the
    /// button comes up, including outside the panel.
    DragStart {
        field: String,
    },
    DragEnd {
        field: String,
    },
}

/// One field as the control channel sees it: what it is called, what it holds,
/// and what it will accept.
#[derive(Debug, Clone)]
pub struct FieldSpec {
    pub name: String,
    pub value: FieldValue,
    pub options: Option<Vec<String>>,
}

#[derive(Debug, Clone, PartialEq)]
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
                revert: false,
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
                revert: false,
            });
        })?;
    Ok(())
}

/// RmlUi key identifiers (`Rml::Input::KeyIdentifier`).
const KI_NUMPADENTER: i32 = 61;
const KI_RETURN: i32 = 72;
const KI_ESCAPE: i32 = 81;

/// Commit a text field on Enter, or throw the edit away on Escape.
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
            if !found {
                return;
            }
            if key == KI_RETURN || key == KI_NUMPADENTER {
                cq.borrow_mut().push(CommitRequest {
                    field: name.clone(),
                    from_blur: false,
                    revert: false,
                });
            } else if key == KI_ESCAPE {
                cq.borrow_mut().push(CommitRequest {
                    field: name.clone(),
                    from_blur: false,
                    revert: true,
                });
            }
        })?;
    Ok(())
}

/// Listen for the events a field drag is made of.
///
/// The drag is bracketed by RmlUi's own `dragstart`/`dragend`, not by the
/// engine's mouse callbacks. The engine hands mouse input to its RmlUi contexts
/// *before* its event clients, and RmlUi consumes a press over the panel -- so
/// the plugin's `mouse_press` is never called for a click on a field, never
/// becomes the engine's mouse owner, and never receives `mouse_release`. A drag
/// released outside the panel could not be ended at all.
///
/// RmlUi captures the pointer for a drag, so `dragend` arrives wherever the
/// button comes up, on or off the element. That is the signal to use. (The
/// element must opt in with `drag: drag` in RCSS.)
///
/// `mousedown`/`mouseup` still bracket a *click*, which is what opens the inline
/// editor when the pointer never moved far enough to become a drag.
pub(crate) fn on_pointer(
    interface: &NativeInterfaceRef,
    element: u64,
    name: String,
    interactions: &InteractionQueue,
) -> Result<(), Error> {
    for (event, make) in [
        (
            "mousedown",
            (|field| InteractionEvent::PointerDown { field }) as fn(String) -> InteractionEvent,
        ),
        ("mouseup", |field| InteractionEvent::PointerUp { field }),
        ("dragstart", |field| InteractionEvent::DragStart { field }),
        ("dragend", |field| InteractionEvent::DragEnd { field }),
    ] {
        let queue = interactions.clone();
        let field = name.clone();
        interface
            .rml_ui()
            .element_add_event_listener(element, event, false, move || {
                queue.borrow_mut().push(make(field.clone()));
            })?;
    }
    Ok(())
}

/// Attach a simple tooltip to an element with a known label.
///
/// RmlUi's `title` attribute is useful metadata but the native context does not
/// draw it for us. The shell owns `#native-panel-tooltip`; hover listeners fill
/// and position it independently of the map-object cursor tooltip.
pub(crate) fn bind_tooltip(
    interface: &NativeInterfaceRef,
    document: u64,
    element: u64,
    text: impl Into<String>,
) -> Result<(), Error> {
    bind_tooltip_inner(interface, document, element, text.into(), true)
}

/// Attach tooltip markup that already contains safe RML, such as coloured
/// material-channel availability indicators.
pub(crate) fn bind_tooltip_markup(
    interface: &NativeInterfaceRef,
    document: u64,
    element: u64,
    markup: impl Into<String>,
) -> Result<(), Error> {
    bind_tooltip_inner(interface, document, element, markup.into(), false)
}

// ── DOM helpers ────────────────────────────────────────────────────

pub(crate) use crate::sbc::rml::{element_by_id, escape_rml};

/// Format a float for display with a fixed number of decimals.
pub(crate) fn format_number(value: f32, decimals: usize) -> String {
    format!("{:.*}", decimals, value)
}

/// Whether tooltips are turned off. The e2e harness does that by default: a tip
/// follows the cursor, so it lands in the middle of whatever a scenario is
/// capturing. The scenarios that are *about* tooltips ask for them back.
pub(crate) fn tooltips_hidden() -> bool {
    static OFF: std::sync::OnceLock<bool> = std::sync::OnceLock::new();
    *OFF.get_or_init(|| matches!(std::env::var("SBC_HIDE_TOOLTIPS").as_deref(), Ok("1")))
}

fn bind_tooltip_inner(
    interface: &NativeInterfaceRef,
    document: u64,
    element: u64,
    text: String,
    escape: bool,
) -> Result<(), Error> {
    if tooltips_hidden() {
        return Ok(());
    }
    if text.trim().is_empty() {
        return Ok(());
    }

    let iface = *interface;
    let show_text = text.clone();
    interface
        .rml_ui()
        .element_add_event_listener(element, "mouseover", false, move || {
            let Some(tooltip) = element_by_id(&iface, document, "native-panel-tooltip") else {
                return;
            };
            let Ok(mouse) = iface.input().get_mouse_state() else {
                return;
            };
            let Ok(geom) = iface.display().get_view_geometry() else {
                return;
            };
            let y = geom.viewSizeY as f32 - mouse.y;
            let rml = iface.rml_ui();
            let rendered = if escape {
                escape_rml(&show_text)
            } else {
                show_text.clone()
            };
            let _ = rml.element_set_inner_rml(tooltip, &rendered);
            let _ = rml.element_set_attribute(
                tooltip,
                "style",
                &format!("left: {}px; top: {}px;", mouse.x as i32 + 12, y as i32 + 18),
            );
            let _ = rml.element_set_class(tooltip, "hidden", false);
        })?;

    let iface = *interface;
    interface
        .rml_ui()
        .element_add_event_listener(element, "mouseout", false, move || {
            if let Some(tooltip) = element_by_id(&iface, document, "native-panel-tooltip") {
                let _ = iface.rml_ui().element_set_class(tooltip, "hidden", true);
            }
        })?;
    Ok(())
}

// ── Field trait ────────────────────────────────────────────────────

/// A single form field. Generates its own RML, binds to the document, and can
/// read/write its value from/to the DOM.
pub trait Field {
    fn name(&self) -> &str;
    fn generate_rml(&self) -> String;

    /// Hover text. Bound by the `FieldSet` against the field's own element, so a
    /// field type does not have to do anything to have one.
    fn tooltip(&self) -> Option<&str> {
        None
    }

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

    /// The values this field accepts, for a field that only accepts some: a
    /// dropdown's items. The control channel rejects anything else, which a
    /// dropdown cannot do for itself once its value is just a string.
    fn options(&self) -> Option<&[String]> {
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

    /// Select the whole value while in edit mode (Ctrl+A).
    fn select_edit(&mut self, _interface: &NativeInterfaceRef) {}

    /// End edit mode — switch back to display, without committing.
    fn end_edit(&mut self, _interface: &NativeInterfaceRef) {}
}
