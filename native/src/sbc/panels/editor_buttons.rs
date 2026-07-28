//! The registered editor-button strip's native data-model projection.

use spring_native::{
    prelude::{Error, NativeInterfaceRef},
    RmlDataIconRows, RmlIconRow,
};

use super::{
    field::element_by_id,
    registry::{editors_for, EditorSpec, Tab},
    tooltip::{PanelTooltip, TooltipContent},
    view::{ShellEvent, ShellQueue},
};

const HOST_ID: &str = "editor-button-panel";
const MODEL_NAME: &str = "panel_editor_buttons";
const TEMPLATE: &str = include_str!("editor_buttons.rml");

/// Owns the registered editor controls beneath the tab bar. The registry is
/// projected through a stable RmlUi template instead of regenerating markup.
#[derive(Default)]
pub(crate) struct EditorButtons {
    rows: Option<RmlDataIconRows<'static>>,
    document: Option<u64>,
    tab: Option<Tab>,
    active: Option<&'static str>,
}

impl EditorButtons {
    pub(crate) fn forget(&mut self) {
        self.rows = None;
        self.document = None;
        self.tab = None;
        self.active = None;
    }

    pub(crate) fn render(
        &mut self,
        interface: &NativeInterfaceRef,
        document: u64,
        tab: Tab,
        active: Option<&'static str>,
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

        if self.document != Some(document) {
            self.forget();
            let model = rml.create_data_model(context, MODEL_NAME)?;
            self.rows = Some(model.bind_icon_rows("editors")?);
            rml.element_set_inner_rml(host, TEMPLATE)?;
            self.document = Some(document);
        }

        let specs = editors_for(tab);
        if self.tab != Some(tab) {
            let rows = Self::rows_for(&specs, active);
            if let Some(model_rows) = &self.rows {
                model_rows.set(&rows)?;
            }
            // Changing a tab changes the number and identity of the data-for
            // rows, so bind listeners only after RmlUi has materialized them.
            rml.context_update(context)?;
            for (index, spec) in specs.iter().enumerate() {
                let (button, exists) = rml.element_get_child(host, index as i32)?;
                if !exists {
                    continue;
                }
                tooltip.bind_to(interface, button, TooltipContent::text(spec.tooltip))?;
                let queue = events.clone();
                let name = spec.name;
                rml.element_add_event_listener(button, "click", false, move || {
                    queue.borrow_mut().push(ShellEvent::Editor(name));
                })?;
            }
            self.tab = Some(tab);
            self.active = active;
        }

        if self.active != active {
            self.rows
                .as_ref()
                .expect("editor rows are bound before their markup")
                .set(&Self::rows_for(&specs, active))?;
            self.active = active;
        }
        Ok(())
    }

    fn rows_for(specs: &[&EditorSpec], active: Option<&'static str>) -> Vec<RmlIconRow> {
        specs
            .iter()
            .map(|spec| RmlIconRow {
                label: spec.caption.to_owned(),
                icon: spec.image.to_owned(),
                tooltip: spec.tooltip.to_owned(),
                pressed: Some(spec.name) == active,
                disabled: false,
            })
            .collect()
    }
}
