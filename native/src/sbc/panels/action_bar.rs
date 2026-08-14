//! The project and clipboard toolbar's native data-model projection.

use spring_native::prelude::{Error, NativeInterfaceRef};

use crate::sbc::panels::rows::IconRow;
use crate::sbc::rml::rows::Rows;

use super::{
    field::element_by_id,
    tooltip::{PanelTooltip, TooltipContent},
    view::{ShellEvent, ShellQueue},
};
use crate::sbc::actions::Action;

const HOST_ID: &str = "action-bar";
const MODEL_NAME: &str = "panel_action_bar";
const TEMPLATE: &str = include_str!("action_bar.rml");

/// Owns the small, fixed-shape toolbar model. Its content is data-driven, but
/// its RML stays local to the component rather than inflating the panel shell.
#[derive(Default)]
pub(crate) struct ActionBar {
    rows: Option<Rows<IconRow>>,
    document: Option<u64>,
}

impl ActionBar {
    pub(crate) fn forget(&mut self) {
        self.rows = None;
        self.document = None;
    }

    /// Materialize the action controls once for this document and attach their
    /// behavior after the data-for rows exist.
    pub(crate) fn bind(
        &mut self,
        interface: &NativeInterfaceRef,
        document: u64,
        tooltip: &PanelTooltip,
        events: &ShellQueue,
    ) -> Result<(), Error> {
        let Some(host) = element_by_id(interface, document, HOST_ID) else {
            return Ok(());
        };
        let rml = interface.rml_ui();
        let (context, exists) = rml.document_get_context(document)?;
        if !exists {
            return Ok(());
        }
        if self.document == Some(document) {
            return Ok(());
        }

        let model = rml.create_data_model(context, MODEL_NAME)?;
        let rows = Rows::<IconRow>::bind(&model, "actions")?;

        let queue = events.clone();
        Rows::<IconRow>::on_row(&model, "select", move |index, _| {
            if let Some(action) = Action::TOOLBAR.get(index) {
                queue.borrow_mut().push(ShellEvent::Action(*action));
            }
        })?;
        let host_tooltip = tooltip.clone();
        let iface = *interface;
        Rows::<IconRow>::on_row(&model, "show_tooltip", move |index, _| {
            if let Some(action) = Action::TOOLBAR.get(index) {
                let _ = host_tooltip.show(&iface, &TooltipContent::text(action.tooltip()));
            }
        })?;
        let host_tooltip = tooltip.clone();
        Rows::<IconRow>::on_row(&model, "hide_tooltip", move |_, _| {
            let _ = host_tooltip.hide();
        })?;

        rml.element_set_inner_rml(host, TEMPLATE)?;
        let action_rows = Action::TOOLBAR
            .into_iter()
            .map(|action| {
                let icon = action
                    .icon()
                    .ok_or_else(|| Error::new(1, "toolbar action has no icon"))?;
                Ok(IconRow {
                    label: action.tooltip().to_owned(),
                    icon: icon.to_owned(),
                    tooltip: action.tooltip().to_owned(),
                    pressed: false,
                    disabled: false,
                })
            })
            .collect::<Result<Vec<_>, Error>>()?;
        rows.set(&action_rows)?;

        self.rows = Some(rows);
        self.document = Some(document);
        Ok(())
    }
}
