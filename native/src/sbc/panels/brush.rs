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

use crate::sbc::panels::field::bind_tooltip;
use crate::sbc::rml::{element_by_id, escape_rml};
use crate::sbc::states::{BrushKind, StateRequest};

/// An unset asset field reads as an empty string, not as an absent value.
pub(crate) fn non_empty(value: String) -> Option<String> {
    (!value.is_empty()).then_some(value)
}

/// The direct thumbnail grids use full VFS paths. Asset fields instead pass a
/// relative root to `AssetPicker`, which now defaults to this pack itself.
pub(crate) const ASSETS: &str = "springboard/assets/core";

/// One action button: a caption, the image icon, and the brush it activates.
#[derive(Clone, Copy)]
pub(crate) struct BrushAction {
    pub caption: &'static str,
    pub image: &'static str,
    pub kind: BrushKind,
    pub paint_mode: &'static str,
}

/// The action-button strip an editor renders above its fields.
pub(crate) struct BrushActions {
    actions: &'static [BrushAction],
    /// The active brush, or none when the editor is not painting.
    active: Option<usize>,
    /// Actions the current map cannot support; they render greyed and ignore clicks.
    disabled: Vec<usize>,
    disabled_tooltips: Vec<Option<String>>,
    clicks: Rc<RefCell<Vec<usize>>>,
    request: Option<StateRequest>,
}

impl BrushActions {
    pub(crate) fn new(actions: &'static [BrushAction]) -> Self {
        BrushActions {
            actions,
            active: None,
            disabled: Vec::new(),
            disabled_tooltips: vec![None; actions.len()],
            clicks: Rc::new(RefCell::new(Vec::new())),
            request: None,
        }
    }

    pub(crate) fn generate_rml(&self) -> String {
        let mut html = String::from(r#"<div class="brush-actions">"#);
        for action in self.actions {
            html.push_str(&format!(
                r#"<button id="brush-action-{id}" class="brush-action">
                    <img src="{image}" class="brush-action-icon"/>
                    <span class="brush-action-label">{caption}</span>
                </button>"#,
                id = action.caption.to_lowercase().replace(' ', "-"),
                image = action.image,
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
        for (index, action) in self.actions.iter().enumerate() {
            let id = format!(
                "brush-action-{}",
                action.caption.to_lowercase().replace(' ', "-")
            );
            let Some(button) = element_by_id(interface, document, &id) else {
                continue;
            };
            let tooltip = self.disabled_tooltips[index]
                .as_deref()
                .unwrap_or(action.caption);
            bind_tooltip(interface, document, button, tooltip)?;
            let queue = self.clicks.clone();
            interface
                .rml_ui()
                .element_add_event_listener(button, "click", false, move || {
                    queue.borrow_mut().push(index);
                })?;
        }
        Ok(())
    }

    /// Handle queued clicks. Brush buttons choose a tool; clicking the current
    /// one leaves it selected, matching Chili's non-toggle action tabs.
    pub(crate) fn tick(&mut self, interface: &NativeInterfaceRef, document: u64) {
        for index in self.clicks.borrow_mut().drain(..) {
            let Some(action) = self.actions.get(index) else {
                continue;
            };
            if self.disabled.contains(&index) {
                continue;
            }
            self.active = Some(index);
            self.request = Some(StateRequest::Brush(
                action.kind,
                action.paint_mode.to_string(),
            ));
        }
        self.render(interface, document);
    }

    pub(crate) fn take_request(&mut self) -> Option<StateRequest> {
        self.request.take()
    }

    /// Keep the visual toggle in sync when StateManager leaves the brush
    /// without going through this action strip (for example, Escape).
    pub(crate) fn clear(&mut self, interface: &NativeInterfaceRef, document: u64) {
        self.active = None;
        self.request = None;
        self.render(interface, document);
    }

    /// The active action's paint mode, or none when no brush is active.
    pub(crate) fn selected_paint_mode(&self) -> Option<&'static str> {
        self.active
            .and_then(|index| self.actions.get(index))
            .map(|action| action.paint_mode)
    }

    /// Grey out an action the map cannot support, as Lua disables the DNTS
    /// button on a map with no splat normals. A disabled action also ignores
    /// clicks, so it cannot enter a state that has nothing to paint.
    pub(crate) fn set_enabled(
        &mut self,
        interface: &NativeInterfaceRef,
        document: u64,
        caption: &str,
        enabled: bool,
    ) {
        let reason = (!enabled && caption == "DNTS")
            .then_some("DNTS unavailable: splat textures are not available on this map.");
        self.set_enabled_with_reason(interface, document, caption, enabled, reason);
    }

    pub(crate) fn set_enabled_with_reason(
        &mut self,
        interface: &NativeInterfaceRef,
        document: u64,
        caption: &str,
        enabled: bool,
        reason: Option<&str>,
    ) {
        let Some(index) = self
            .actions
            .iter()
            .position(|action| action.caption == caption)
        else {
            return;
        };
        self.disabled.retain(|i| *i != index);
        self.disabled_tooltips[index] = None;
        if !enabled {
            self.disabled.push(index);
            self.disabled_tooltips[index] = reason.map(str::to_string);
        }
        let id = format!("brush-action-{}", caption.to_lowercase().replace(' ', "-"));
        if let Some(button) = element_by_id(interface, document, &id) {
            let _ = interface
                .rml_ui()
                .element_set_class(button, "disabled", !enabled);
        }
    }

    fn render(&self, interface: &NativeInterfaceRef, document: u64) {
        for (index, action) in self.actions.iter().enumerate() {
            let id = format!(
                "brush-action-{}",
                action.caption.to_lowercase().replace(' ', "-")
            );
            if let Some(button) = element_by_id(interface, document, &id) {
                let _ = interface.rml_ui().element_set_class(
                    button,
                    "pressed",
                    self.active == Some(index),
                );
            }
        }
    }
}
