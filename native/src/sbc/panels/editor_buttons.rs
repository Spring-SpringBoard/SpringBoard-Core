//! The registered editor-button strip's native data-model projection.

use std::cell::Cell;
use std::rc::Rc;

use spring_native::prelude::{Error, NativeInterfaceRef};

use crate::sbc::panels::rows::IconRow;
use crate::sbc::rml::rows::Rows;

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
    rows: Option<Rows<IconRow>>,
    document: Option<u64>,
    tab: Option<Tab>,
    active: Option<&'static str>,
    /// The tab whose specs the bound event handlers resolve indices against.
    /// The handlers outlive any one tab, so they read it rather than capture it.
    handler_tab: Rc<Cell<Option<Tab>>>,
}

impl EditorButtons {
    pub(crate) fn forget(&mut self) {
        self.rows = None;
        self.document = None;
        self.tab = None;
        self.active = None;
        self.handler_tab.set(None);
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
            self.rows = Some(Rows::<IconRow>::bind(&model, "editors")?);
            self.bind_events(interface, &model, tooltip, events)?;
            rml.element_set_inner_rml(host, TEMPLATE)?;
            self.document = Some(document);
        }

        let specs = editors_for(tab);
        if self.tab != Some(tab) {
            let rows = Self::rows_for(&specs, active);
            if let Some(model_rows) = &self.rows {
                model_rows.set(&rows)?;
            }
            self.tab = Some(tab);
            self.active = active;
            self.handler_tab.set(Some(tab));
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

    fn bind_events(
        &self,
        interface: &NativeInterfaceRef,
        model: &spring_native::RmlDataModel<'static>,
        tooltip: &PanelTooltip,
        events: &ShellQueue,
    ) -> Result<(), Error> {
        let tab = self.handler_tab.clone();
        let queue = events.clone();
        Rows::<IconRow>::on_row(model, "select", move |index, _| {
            if let Some(spec) = spec_at(&tab, index) {
                queue.borrow_mut().push(ShellEvent::Editor(spec.name));
            }
        })?;

        let tab = self.handler_tab.clone();
        let host = tooltip.clone();
        let iface = *interface;
        Rows::<IconRow>::on_row(model, "show_tooltip", move |index, _| {
            if let Some(spec) = spec_at(&tab, index) {
                let _ = host.show(&iface, &TooltipContent::text(spec.tooltip));
            }
        })?;

        let host = tooltip.clone();
        Rows::<IconRow>::on_row(model, "hide_tooltip", move |_, _| {
            let _ = host.hide();
        })
    }

    fn rows_for(specs: &[&EditorSpec], active: Option<&'static str>) -> Vec<IconRow> {
        specs
            .iter()
            .map(|spec| IconRow {
                label: spec.caption.to_owned(),
                icon: spec.image.to_owned(),
                tooltip: spec.tooltip.to_owned(),
                pressed: Some(spec.name) == active,
                disabled: false,
            })
            .collect()
    }
}

fn spec_at(tab: &Rc<Cell<Option<Tab>>>, index: usize) -> Option<&'static EditorSpec> {
    editors_for(tab.get()?).get(index).copied()
}
