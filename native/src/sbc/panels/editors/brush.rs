//! Shared plumbing for the Map tab's brush editors.
//!
//! A brush editor's fields are *brush state*, not engine state: nothing is
//! dispatched when they change. They are pushed into the shared `BrushSettings`
//! model, which the active editing state paints with.
//!
//! Each editor also has a strip of action buttons (Lua's `TabbedPanelLabel`s:
//! "Add", "Set", "Smooth", ...). Clicking one enters the matching editing state;
//! clicking the active one leaves it.

use std::cell::RefCell;
use std::rc::Rc;

use spring_native::prelude::{Error, NativeInterfaceRef};

use crate::sbc::panels::fields::AssetField;
use crate::sbc::rml::{element_by_id, escape_rml};
use crate::sbc::states::{BrushKind, StateRequest};

/// An unset asset field reads as an empty string, not as an absent value.
pub(crate) fn non_empty(value: String) -> Option<String> {
    (!value.is_empty()).then_some(value)
}

/// Where SpringBoard's shipped assets live. Lua resolves an editor's `rootDir`
/// against the folders `AssetsManager` registers; this is the only one, so the
/// full VFS path is spelled out rather than reinventing that indirection.
pub(crate) const ASSETS: &str = "springboard/assets/core";

/// Every brush is shaped by a pattern from the same directory.
pub(crate) fn pattern_field() -> Box<AssetField> {
    Box::new(
        AssetField::new(
            "patternTexture",
            "Pattern",
            &format!("{ASSETS}/brush_patterns/terrain"),
        )
        .extensions(&[".png", ".jpg", ".tga", ".dds", ".bmp"]),
    )
}

/// One action button: a caption and the brush it activates.
#[derive(Clone, Copy)]
pub(crate) struct BrushAction {
    pub caption: &'static str,
    pub kind: BrushKind,
}

/// The action-button strip an editor renders above its fields.
pub(crate) struct BrushActions {
    actions: &'static [BrushAction],
    /// The active brush, or none when the editor is not painting.
    active: Option<BrushKind>,
    clicks: Rc<RefCell<Vec<BrushKind>>>,
    request: Option<StateRequest>,
}

impl BrushActions {
    pub(crate) fn new(actions: &'static [BrushAction]) -> Self {
        BrushActions {
            actions,
            active: None,
            clicks: Rc::new(RefCell::new(Vec::new())),
            request: None,
        }
    }

    pub(crate) fn generate_rml(&self) -> String {
        let mut html = String::from(r#"<div class="brush-actions">"#);
        for action in self.actions {
            html.push_str(&format!(
                r#"<button id="brush-action-{id}" class="brush-action">{caption}</button>"#,
                id = action.caption.to_lowercase().replace(' ', "-"),
                caption = escape_rml(action.caption),
            ));
        }
        html.push_str("</div>");
        html
    }

    pub(crate) fn bind(
        &mut self,
        interface: &NativeInterfaceRef,
        document: u64,
    ) -> Result<(), Error> {
        for action in self.actions {
            let id = format!(
                "brush-action-{}",
                action.caption.to_lowercase().replace(' ', "-")
            );
            let Some(button) = element_by_id(interface, document, &id) else {
                continue;
            };
            let queue = self.clicks.clone();
            let kind = action.kind;
            interface
                .rml_ui()
                .element_add_event_listener(button, "click", false, move || {
                    queue.borrow_mut().push(kind);
                })?;
        }
        Ok(())
    }

    /// Handle queued clicks. Toggling: the active button turns the brush off.
    pub(crate) fn tick(&mut self, interface: &NativeInterfaceRef, document: u64) {
        for kind in self.clicks.borrow_mut().drain(..) {
            if self.active == Some(kind) {
                self.active = None;
                self.request = Some(StateRequest::Default);
            } else {
                self.active = Some(kind);
                self.request = Some(StateRequest::Brush(kind));
            }
        }
        self.render(interface, document);
    }

    fn render(&self, interface: &NativeInterfaceRef, document: u64) {
        for action in self.actions {
            let id = format!(
                "brush-action-{}",
                action.caption.to_lowercase().replace(' ', "-")
            );
            if let Some(button) = element_by_id(interface, document, &id) {
                let _ = interface.rml_ui().element_set_class(
                    button,
                    "pressed",
                    self.active == Some(action.kind),
                );
            }
        }
    }

    pub(crate) fn take_request(&mut self) -> Option<StateRequest> {
        self.request.take()
    }
}

/// The `Editor` methods every brush editor implements identically: fields are
/// local state, so a change dispatches nothing.
macro_rules! brush_editor_boilerplate {
    () => {
        fn bind_fields(
            &mut self,
            interface: &NativeInterfaceRef,
            document: u64,
            changes: &ChangeQueue,
            interactions: &InteractionQueue,
        ) -> Result<(), Error> {
            self.actions.bind(interface, document)?;
            self.fields.bind(interface, document, changes, interactions)
        }

        fn write_field_values(&self, interface: &NativeInterfaceRef) -> Result<(), Error> {
            self.fields.write_values(interface)
        }

        /// Brush state: read the DOM so the field holds the new value, and emit
        /// nothing. The brush reads it when it paints.
        fn process_change(
            &mut self,
            name: &str,
            interface: &NativeInterfaceRef,
            _next: &mut u64,
        ) -> Vec<String> {
            self.fields.read(name, interface);
            vec![]
        }

        fn process_drag_end(&mut self, _name: &str, _next: &mut u64) -> Vec<String> {
            vec![]
        }

        fn tick(
            &mut self,
            interface: &NativeInterfaceRef,
            document: u64,
            _next: &mut u64,
        ) -> Vec<String> {
            self.actions.tick(interface, document);
            vec![]
        }

        fn take_state_request(&mut self) -> Option<$crate::sbc::states::StateRequest> {
            self.actions.take_request()
        }

        fn drag_field(&mut self, name: &str, dx: f32, interface: &NativeInterfaceRef) -> bool {
            self.fields.drag(name, dx, interface)
        }

        fn drag_end_field(&mut self, name: &str, interface: &NativeInterfaceRef) -> bool {
            self.fields.drag_end(name, interface)
        }

        fn begin_edit_field(&mut self, name: &str, interface: &NativeInterfaceRef) {
            self.fields.begin_edit(name, interface)
        }

        fn cancel_edit_field(&mut self, name: &str, interface: &NativeInterfaceRef) {
            self.fields.cancel_edit(name, interface)
        }

        fn field_value(&self, name: &str) -> FieldValue {
            self.fields.value(name)
        }

        fn set_field_value(
            &mut self,
            name: &str,
            value: FieldValue,
            interface: &NativeInterfaceRef,
        ) {
            self.fields
                .set($crate::sbc::panels::editor_base::resolve_base(name), value);
            let _ = self.fields.write_values(interface);
        }

        fn field_asset(&self, name: &str) -> Option<(String, Vec<String>)> {
            self.fields.asset_info(name)
        }
    };
}

pub(crate) use brush_editor_boilerplate;
