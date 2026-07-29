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

use spring_native::{
    prelude::{Error, NativeInterfaceRef},
    RmlDataIconRows, RmlDataModel, RmlIconRow,
};

use crate::sbc::panels::tooltip::{PanelTooltip, TooltipContent};
use crate::sbc::rml::element_by_id;
use crate::sbc::states::{MapBrush, StateRequest};

/// An unset asset field reads as an empty string, not as an absent value.
pub(crate) fn non_empty(value: String) -> Option<String> {
    (!value.is_empty()).then_some(value)
}

/// One action button: a caption, the image icon, and the brush it activates.
#[derive(Clone, Copy)]
pub(crate) struct BrushAction {
    pub caption: &'static str,
    pub image: &'static str,
    pub tool: &'static dyn MapBrush,
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
    tooltip: Option<PanelTooltip>,
    /// The action definitions are fixed for an editor, but their captions and
    /// icons still cross into RmlUi as typed values rather than generated RML.
    rows: Option<RmlDataIconRows<'static>>,
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
            tooltip: None,
            rows: None,
        }
    }

    pub(crate) fn generate_rml(&self) -> String {
        r#"<div id="brush-actions" class="brush-actions">
            <button data-for="action : brush_actions" data-if="action.visible" class="brush-action" data-class-pressed="action.pressed" data-class-disabled="action.disabled">
                <img data-attr-src="action.icon" class="brush-action-icon"/>
                <span class="brush-action-label">{{ action.label }}</span>
            </button>
        </div>"#
            .to_owned()
    }

    pub(crate) fn prepare_data_model(
        &mut self,
        model: &RmlDataModel<'static>,
    ) -> Result<(), Error> {
        let rows = model.bind_icon_rows("brush_actions")?;
        rows.set(&self.rows_for())?;
        self.rows = Some(rows);
        Ok(())
    }

    pub(crate) fn bind(
        &mut self,
        interface: &NativeInterfaceRef,
        document: u64,
    ) -> Result<(), Error> {
        for (index, action) in self.actions.iter().enumerate() {
            let Some(button) = self.button(interface, document, index) else {
                continue;
            };
            let tooltip = self.disabled_tooltips[index]
                .as_deref()
                .unwrap_or(action.caption);
            if let Some(tooltip_host) = &self.tooltip {
                tooltip_host.bind_to(interface, button, TooltipContent::text(tooltip))?;
            }
            let queue = self.clicks.clone();
            interface
                .rml_ui()
                .element_add_event_listener(button, "click", false, move || {
                    queue.borrow_mut().push(index);
                })?;
        }
        Ok(())
    }

    pub(crate) fn set_tooltip_host(&mut self, tooltip: PanelTooltip) {
        self.tooltip = Some(tooltip);
    }

    /// Handle queued clicks. Brush buttons choose a tool; clicking the current
    /// one leaves it selected, matching Chili's non-toggle action tabs.
    pub(crate) fn tick(&mut self) {
        for index in self.clicks.borrow_mut().drain(..) {
            let Some(action) = self.actions.get(index) else {
                continue;
            };
            if self.disabled.contains(&index) {
                continue;
            }
            self.active = Some(index);
            self.request = Some(StateRequest::Brush(
                action.tool,
                action.paint_mode.to_string(),
            ));
        }
        self.render();
    }

    pub(crate) fn take_request(&mut self) -> Option<StateRequest> {
        self.request.take()
    }

    /// Keep the visual toggle in sync when StateManager leaves the brush
    /// without going through this action strip (for example, Escape).
    pub(crate) fn clear(&mut self) {
        self.active = None;
        self.request = None;
        self.render();
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
    pub(crate) fn set_enabled(&mut self, caption: &str, enabled: bool) {
        let reason = (!enabled && caption == "DNTS")
            .then_some("DNTS unavailable: splat textures are not available on this map.");
        self.set_enabled_with_reason(caption, enabled, reason);
    }

    pub(crate) fn set_enabled_with_reason(
        &mut self,
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
        self.render();
    }

    fn render(&self) {
        if let Some(rows) = &self.rows {
            let _ = rows.set(&self.rows_for());
        }
    }

    fn rows_for(&self) -> Vec<RmlIconRow> {
        self.actions
            .iter()
            .enumerate()
            .map(|(index, action)| RmlIconRow {
                label: action.caption.to_owned(),
                icon: action.image.to_owned(),
                tooltip: action.caption.to_owned(),
                pressed: self.active == Some(index),
                disabled: self.disabled.contains(&index),
            })
            .collect()
    }

    /// Rows are materialised by the editor's one rebuild-time context update,
    /// before action listeners bind. Indexing the fixed action definition list
    /// keeps these implementation details out of generated ids and markup.
    fn button(&self, interface: &NativeInterfaceRef, document: u64, index: usize) -> Option<u64> {
        let host = element_by_id(interface, document, "brush-actions")?;
        let (button, exists) = interface
            .rml_ui()
            .element_get_child(host, index as i32)
            .ok()?;
        exists.then_some(button)
    }
}
