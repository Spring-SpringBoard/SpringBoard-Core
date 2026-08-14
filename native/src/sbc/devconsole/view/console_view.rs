use spring_native::prelude::{Error, NativeInterfaceRef};

use crate::sbc::devconsole::log_model::LogModel;
use crate::sbc::devconsole::toolbar_actions::ToolbarAction;
use crate::sbc::rml;

use super::log_panel::LogPanel;
use super::toolbar_view::{ToggleState, ToolbarView};
use super::UI_STYLE;

const UI_CONTEXT: &str = "sbc_dev_console";
const UI_BODY: &str = include_str!("ui.rml");

pub(crate) struct ConsoleView {
    context: Option<u64>,
    document: Option<u64>,
    hidden: Option<spring_native::RmlDataVariable<'static, bool>>,
    visible: bool,
    popup_on_error: bool,
    toggle_refresh_pending: bool,
    toolbar: Option<ToolbarView>,
    log_panel: Option<LogPanel>,
}

impl Default for ConsoleView {
    fn default() -> Self {
        ConsoleView {
            context: None,
            document: None,
            hidden: None,
            visible: true,
            popup_on_error: true,
            toggle_refresh_pending: false,
            toolbar: None,
            log_panel: None,
        }
    }
}

impl ConsoleView {
    pub(crate) fn is_ready(&self) -> bool {
        self.context.is_some() && self.toolbar.is_some() && self.log_panel.is_some()
    }

    pub(crate) fn visible(&self) -> bool {
        self.visible
    }

    pub(crate) fn set_hidden_at_startup(&mut self) {
        self.visible = false;
        self.popup_on_error = false;
    }

    pub(crate) fn context_is_alive(&self, interface: &NativeInterfaceRef) -> bool {
        rml::context_is_alive(interface, UI_CONTEXT, self.context)
    }

    pub(crate) fn create_if_needed(
        &mut self,
        interface: &NativeInterfaceRef,
    ) -> Result<bool, Error> {
        if self.is_ready() {
            if self.context_is_alive(interface) {
                return Ok(false);
            }
            self.forget();
        }
        let rml = interface.rml_ui();
        if !rml.is_ready()? {
            return Ok(false);
        }

        let (ctx, ok) = rml.create_context(UI_CONTEXT)?;
        if !ok {
            return Ok(false);
        }
        let data_model = rml.create_data_model(ctx, "dev_console")?;
        self.hidden = Some(data_model.bind("hidden", !self.visible)?);
        let mut log_panel = LogPanel::new(&data_model)?;
        let mut toolbar = ToolbarView::new(&data_model)?;

        let (doc, ok) = rml.context_create_document(ctx, "body")?;
        if !ok {
            self.hidden = None;
            return Ok(false);
        }
        rml.document_set_title(doc, "Developer Console")?;
        rml.document_append_to_style_sheet(doc, UI_STYLE)?;
        rml.element_set_inner_rml(doc, UI_BODY)?;
        rml.document_show(doc, spring_native::RmlDocumentShowOptions::default())?;

        log_panel.attach(interface, doc)?;
        toolbar.attach(interface, doc)?;

        self.context = Some(ctx);
        self.document = Some(doc);
        self.log_panel = Some(log_panel);
        self.toolbar = Some(toolbar);

        let visible = self.visible;
        self.set_visible(interface, visible)?;
        Ok(true)
    }

    pub(crate) fn set_visible(
        &mut self,
        interface: &NativeInterfaceRef,
        visible: bool,
    ) -> Result<(), Error> {
        self.visible = visible;
        let _ = interface;
        if let Some(hidden) = &self.hidden {
            hidden.set(!visible)?;
        }
        Ok(())
    }

    pub(crate) fn forget(&mut self) {
        self.context = None;
        self.document = None;
        self.hidden = None;
        self.toolbar = None;
        self.log_panel = None;
    }

    pub(crate) fn dispose(&mut self, interface: &NativeInterfaceRef) {
        if !self.context_is_alive(interface) {
            self.forget();
            return;
        }
        let rml = interface.rml_ui();
        self.hidden = None;
        self.toolbar = None;
        self.log_panel = None;
        if let Some(doc) = self.document.take() {
            let _ = rml.document_close(doc);
        }
        if let Some(ctx) = self.context.take() {
            let _ = rml.remove_context(ctx);
        }
    }

    pub(crate) fn process_log_selection(&mut self, model: &mut LogModel) {
        if let Some(panel) = &mut self.log_panel {
            panel.process_selection(model);
        }
    }

    pub(crate) fn select_all_log(&mut self, model: &mut LogModel) {
        if let Some(panel) = &mut self.log_panel {
            panel.select_all(model);
        }
    }

    pub(crate) fn copy_log_selection(&self, model: &LogModel, interface: &NativeInterfaceRef) {
        if let Some(panel) = &self.log_panel {
            panel.copy_selection(model, interface);
        }
    }

    pub(crate) fn render_log(
        &mut self,
        model: &mut LogModel,
        interface: &NativeInterfaceRef,
    ) -> Result<(), Error> {
        if let Some(panel) = &mut self.log_panel {
            panel.render_if_dirty(model, interface)?;
        }
        Ok(())
    }

    pub(crate) fn popup_on_error(&self) -> bool {
        self.popup_on_error
    }

    pub(crate) fn toggle_popup_on_error(&mut self) {
        self.popup_on_error = !self.popup_on_error;
        self.request_toggle_refresh();
    }

    pub(crate) fn request_toggle_refresh(&mut self) {
        self.toggle_refresh_pending = true;
    }

    pub(crate) fn take_toggle_refresh(&mut self) -> bool {
        std::mem::take(&mut self.toggle_refresh_pending)
    }

    pub(crate) fn render_toggles(&self, state: ToggleState) -> Result<(), Error> {
        self.toolbar.as_ref().unwrap().render_toggles(state)
    }

    pub(crate) fn drain_toolbar_actions(&self) -> Vec<ToolbarAction> {
        self.toolbar.as_ref().unwrap().drain_actions()
    }
}
