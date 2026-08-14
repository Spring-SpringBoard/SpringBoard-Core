//! Shared plumbing for the Map tab's brush editors.
//!
//! A brush editor's fields are *brush state*, not engine state: nothing is
//! dispatched when they change. They are pushed into the shared `BrushSettings`
//! model, which the active editing state paints with.
//!
//! Each editor also has a strip of action buttons (Lua's `TabbedPanelLabel`s:
//! "Add", "Set", "Smooth", ...). Clicking one enters the matching editing state;
//! clicking the active one leaves it.

use std::cell::{Cell, RefCell};
use std::rc::Rc;

use spring_native::{
    prelude::{Error, NativeInterfaceRef},
    RmlDataModel,
};

use crate::sbc::panels::rows::IconRow;
use crate::sbc::panels::tooltip::{PanelTooltip, TooltipContent};
use crate::sbc::rml::rows::Rows;
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
    /// Hover text by row index, so the event handlers answer without borrowing
    /// the strip. Refreshed whenever the rows are written.
    hover_tooltips: Rc<RefCell<Vec<String>>>,
    clicks: Rc<RefCell<Vec<usize>>>,
    request: Option<StateRequest>,
    tooltip: Rc<RefCell<Option<PanelTooltip>>>,
    engine: Rc<Cell<Option<NativeInterfaceRef>>>,
    /// The action definitions are fixed for an editor, but their captions and
    /// icons still cross into RmlUi as typed values rather than generated RML.
    rows: Option<Rows<IconRow>>,
}

impl BrushActions {
    pub(crate) fn new(actions: &'static [BrushAction]) -> Self {
        BrushActions {
            actions,
            active: None,
            disabled: Vec::new(),
            disabled_tooltips: vec![None; actions.len()],
            hover_tooltips: Rc::new(RefCell::new(Vec::new())),
            clicks: Rc::new(RefCell::new(Vec::new())),
            request: None,
            tooltip: Rc::new(RefCell::new(None)),
            engine: Rc::new(Cell::new(None)),
            rows: None,
        }
    }

    pub(crate) fn generate_rml(&self) -> String {
        r#"<div id="brush-actions" class="brush-actions">
            <button data-for="action : brush_actions" data-if="action.visible" class="brush-action" data-class-pressed="action.pressed" data-class-disabled="action.disabled" data-event-click="select(it_index)" data-event-mouseover="show_tooltip(it_index)" data-event-mouseout="hide_tooltip(it_index)">
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
        let rows = Rows::<IconRow>::bind(model, "brush_actions")?;
        rows.set(&self.rows_for())?;
        self.refresh_hover_tooltips();
        self.rows = Some(rows);

        let queue = self.clicks.clone();
        Rows::<IconRow>::on_row(model, "select", move |index, _| {
            queue.borrow_mut().push(index);
        })?;
        // The tooltip host and the interface are supplied after this runs, so
        // the handlers read them at event time rather than capturing them.
        let tooltips = self.hover_tooltips.clone();
        let host = self.tooltip.clone();
        let engine = self.engine.clone();
        Rows::<IconRow>::on_row(model, "show_tooltip", move |index, _| {
            let (Some(host), Some(iface)) = (host.borrow().clone(), engine.get()) else {
                return;
            };
            if let Some(text) = tooltips.borrow().get(index) {
                let _ = host.show(&iface, &TooltipContent::text(text));
            }
        })?;
        let host = self.tooltip.clone();
        Rows::<IconRow>::on_row(model, "hide_tooltip", move |_, _| {
            if let Some(host) = host.borrow().as_ref() {
                let _ = host.hide();
            }
        })?;
        Ok(())
    }

    fn refresh_hover_tooltips(&self) {
        *self.hover_tooltips.borrow_mut() = self
            .actions
            .iter()
            .enumerate()
            .map(|(index, action)| {
                self.disabled_tooltips[index]
                    .as_deref()
                    .unwrap_or(action.caption)
                    .to_owned()
            })
            .collect();
    }

    pub(crate) fn set_tooltip_host(&mut self, tooltip: PanelTooltip) {
        *self.tooltip.borrow_mut() = Some(tooltip);
    }

    pub(crate) fn set_engine(&self, interface: &NativeInterfaceRef) {
        self.engine.set(Some(*interface));
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
        self.refresh_hover_tooltips();
        if let Some(rows) = &self.rows {
            let _ = rows.set(&self.rows_for());
        }
    }

    fn rows_for(&self) -> Vec<IconRow> {
        self.actions
            .iter()
            .enumerate()
            .map(|(index, action)| IconRow {
                label: action.caption.to_owned(),
                icon: action.image.to_owned(),
                tooltip: action.caption.to_owned(),
                pressed: self.active == Some(index),
                disabled: self.disabled.contains(&index),
            })
            .collect()
    }
}
