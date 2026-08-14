//! The top-level panel tab strip's native data-model projection.

use spring_native::prelude::{Error, NativeInterfaceRef};

use crate::sbc::panels::rows::ChoiceRow;
use crate::sbc::rml::rows::Rows;

use super::{
    field::element_by_id,
    registry::Tab,
    view::{ShellEvent, ShellQueue},
};

const HOST_ID: &str = "tab-bar";
const MODEL_NAME: &str = "panel_tabs";
const TEMPLATE: &str = include_str!("tab_bar.rml");

/// Owns the top-level tab controls, including the development-only tab when it
/// was enabled before the registry first initialized.
#[derive(Default)]
pub(crate) struct TabBar {
    rows: Option<Rows<ChoiceRow>>,
    document: Option<u64>,
    tabs: Vec<Tab>,
    current: Option<Tab>,
}

impl TabBar {
    pub(crate) fn forget(&mut self) {
        self.rows = None;
        self.document = None;
        self.tabs.clear();
        self.current = None;
    }

    pub(crate) fn render(
        &mut self,
        interface: &NativeInterfaceRef,
        document: u64,
        current: Tab,
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
            let rows = Rows::<ChoiceRow>::bind(&model, "tabs")?;
            self.tabs = Tab::all();
            let tabs = self.tabs.clone();
            let queue = events.clone();
            Rows::<ChoiceRow>::on_row(&model, "select", move |index, _| {
                if let Some(tab) = tabs.get(index) {
                    queue.borrow_mut().push(ShellEvent::Tab(*tab));
                }
            })?;
            rml.element_set_inner_rml(host, TEMPLATE)?;
            rows.set(&self.rows_for(current))?;
            self.rows = Some(rows);
            self.document = Some(document);
            self.current = Some(current);
        }

        if self.current != Some(current) {
            self.rows
                .as_ref()
                .expect("tab rows are bound before their markup")
                .set(&self.rows_for(current))?;
            self.current = Some(current);
        }
        Ok(())
    }

    fn rows_for(&self, current: Tab) -> Vec<ChoiceRow> {
        self.tabs
            .iter()
            .map(|tab| ChoiceRow {
                label: tab.as_str().to_owned(),
                detail: String::new(),
                selected: *tab == current,
                highlighted: false,
            })
            .collect()
    }
}
