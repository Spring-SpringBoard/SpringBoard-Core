//! The top-level panel tab strip's native data-model projection.

use spring_native::{
    prelude::{Error, NativeInterfaceRef},
    RmlDataTextRows, RmlTextRow,
};

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
    rows: Option<RmlDataTextRows<'static>>,
    document: Option<u64>,
    tabs: Vec<Tab>,
}

impl TabBar {
    pub(crate) fn forget(&mut self) {
        self.rows = None;
        self.document = None;
        self.tabs.clear();
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
            let rows = model.bind_text_rows("tabs")?;
            self.tabs = Tab::all();
            let tab_rows = self
                .tabs
                .iter()
                .map(|tab| RmlTextRow {
                    text: tab.as_str().to_owned(),
                    muted: false,
                })
                .collect::<Vec<_>>();
            rml.element_set_inner_rml(host, TEMPLATE)?;
            rows.set(&tab_rows)?;
            rml.context_update(context)?;
            for (index, tab) in self.tabs.iter().copied().enumerate() {
                let (button, exists) = rml.element_get_child(host, index as i32)?;
                if !exists {
                    continue;
                }
                let queue = events.clone();
                rml.element_add_event_listener(button, "click", false, move || {
                    queue.borrow_mut().push(ShellEvent::Tab(tab));
                })?;
            }
            self.rows = Some(rows);
            self.document = Some(document);
        }

        for (index, tab) in self.tabs.iter().copied().enumerate() {
            let (button, exists) = rml.element_get_child(host, index as i32)?;
            if exists {
                rml.element_set_class(button, "active", tab == current)?;
            }
        }
        Ok(())
    }
}
