//! The panel-control tooltip surface.
//!
//! Controls describe a tooltip semantically. This host owns the RmlUi model,
//! DOM positioning, and event-time updates, so callers never generate markup
//! or depend on its data-binding lifecycle.

use spring_native::{
    prelude::{Error, NativeInterfaceRef},
    RmlDataModel, RmlDataStatusRows, RmlDataVariable, RmlPixels, RmlStatusRow,
};

#[derive(Clone, Debug, PartialEq, Eq)]
pub(crate) struct TooltipStatus {
    pub(crate) label: String,
    pub(crate) positive: bool,
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub(crate) struct TooltipContent {
    pub(crate) title: String,
    pub(crate) statuses: Vec<TooltipStatus>,
}

impl TooltipContent {
    pub(crate) fn text(title: impl Into<String>) -> Self {
        TooltipContent {
            title: title.into(),
            statuses: Vec::new(),
        }
    }

    pub(crate) fn statuses(title: impl Into<String>, statuses: Vec<TooltipStatus>) -> Self {
        TooltipContent {
            title: title.into(),
            statuses,
        }
    }
}

/// Cloneable callback handle for the one panel tooltip. Its opaque model
/// handles remain engine-owned; the `PanelView` owns their document lifetime.
#[derive(Clone)]
pub(crate) struct PanelTooltip {
    title: RmlDataVariable<'static, String>,
    hidden: RmlDataVariable<'static, bool>,
    has_statuses: RmlDataVariable<'static, bool>,
    statuses: RmlDataStatusRows<'static>,
    left: RmlDataVariable<'static, RmlPixels>,
    top: RmlDataVariable<'static, RmlPixels>,
}

impl PanelTooltip {
    /// Bind before parsing the shell that references this model. The document
    /// handle is attached afterwards because RmlUi resolves data bindings while
    /// it parses the element, not when the first value is written.
    pub(crate) fn bind(model: &RmlDataModel<'static>) -> Result<Self, Error> {
        Ok(PanelTooltip {
            title: model.bind("title", String::new())?,
            hidden: model.bind("hidden", true)?,
            has_statuses: model.bind("has_statuses", false)?,
            statuses: model.bind_status_rows("statuses")?,
            left: model.bind("left", RmlPixels(0.0))?,
            top: model.bind("top", RmlPixels(0.0))?,
        })
    }

    pub(crate) fn bind_to(
        &self,
        interface: &NativeInterfaceRef,
        element: u64,
        content: TooltipContent,
    ) -> Result<(), Error> {
        if super::field::tooltips_hidden() || content.title.trim().is_empty() {
            return Ok(());
        }

        let host = self.clone();
        let iface = *interface;
        interface
            .rml_ui()
            .element_add_event_listener(element, "mouseover", false, move || {
                let _ = host.show(&iface, &content);
            })?;

        let host = self.clone();
        let iface = *interface;
        interface
            .rml_ui()
            .element_add_event_listener(element, "mouseout", false, move || {
                let _ = host.hide();
                let _ = iface;
            })?;
        Ok(())
    }

    fn show(&self, interface: &NativeInterfaceRef, content: &TooltipContent) -> Result<(), Error> {
        let mouse = interface.input().get_mouse_state()?;
        let geom = interface.display().get_view_geometry()?;
        let y = geom.viewSizeY as f32 - mouse.y;
        self.title.set(content.title.clone())?;
        self.has_statuses.set(!content.statuses.is_empty())?;
        self.statuses.set(
            &content
                .statuses
                .iter()
                .map(|status| RmlStatusRow {
                    label: status.label.clone(),
                    positive: status.positive,
                })
                .collect::<Vec<_>>(),
        )?;
        self.hidden.set(false)?;
        self.left.set(RmlPixels(mouse.x + 12.0))?;
        self.top.set(RmlPixels(y + 18.0))?;
        Ok(())
    }

    fn hide(&self) -> Result<(), Error> {
        self.hidden.set(true)
    }
}
