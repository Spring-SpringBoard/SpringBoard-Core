//! The project and clipboard toolbar's native data-model projection.

use spring_native::{
    prelude::{Error, NativeInterfaceRef},
    RmlDataIconRows, RmlIconRow,
};

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
    rows: Option<RmlDataIconRows<'static>>,
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
        if self.document == Some(document) {
            return Ok(());
        }
        let Some(host) = element_by_id(interface, document, HOST_ID) else {
            return Ok(());
        };
        let rml = interface.rml_ui();
        let (context, exists) = rml.document_get_context(document)?;
        if !exists {
            return Ok(());
        }

        let model = rml.create_data_model(context, MODEL_NAME)?;
        let rows = model.bind_icon_rows("actions")?;
        rml.element_set_inner_rml(host, TEMPLATE)?;
        let action_rows = Action::TOOLBAR
            .into_iter()
            .map(|action| {
                let icon = action
                    .icon()
                    .ok_or_else(|| Error::new(1, "toolbar action has no icon"))?;
                Ok(RmlIconRow {
                    label: action.tooltip().to_owned(),
                    icon: icon.to_owned(),
                    tooltip: action.tooltip().to_owned(),
                    pressed: false,
                    disabled: false,
                })
            })
            .collect::<Result<Vec<_>, Error>>()?;
        rows.set(&action_rows)?;
        // RmlUi creates the data-for elements on update, before native event
        // listeners are attached to the concrete buttons.
        rml.context_update(context)?;

        for (index, action) in Action::TOOLBAR.into_iter().enumerate() {
            let (button, exists) = rml.element_get_child(host, index as i32)?;
            if !exists {
                continue;
            }
            tooltip.bind_to(interface, button, TooltipContent::text(action.tooltip()))?;
            let queue = events.clone();
            rml.element_add_event_listener(button, "click", false, move || {
                queue.borrow_mut().push(ShellEvent::Action(action));
            })?;
        }

        self.rows = Some(rows);
        self.document = Some(document);
        Ok(())
    }
}
