//! The dev console's RmlUi context, document and toolbar.

use std::cell::RefCell;
use std::rc::Rc;

use spring_native::prelude::{Error, NativeInterfaceRef};

use crate::sbc::devconsole::actions::Action;
use crate::sbc::devconsole::log::LogLine;
use crate::sbc::rml::{element_by_id, escape_rml};

const UI_CONTEXT: &str = "sbc_dev_console";
const UI_BODY: &str = include_str!("ui.rml");
const UI_STYLE: &str = include_str!("ui.rcss");

pub(crate) type ActionQueue = Rc<RefCell<Vec<Action>>>;

/// Which toggles are lit. Read from the engine where it owns the state
/// (cheating, LOS, god mode) and from the console where it does not.
#[derive(Debug, Clone, Copy, Default)]
pub(crate) struct ToggleState {
    pub problems_only: bool,
    pub popup_on_error: bool,
    pub visible: bool,
    pub cheating: bool,
    pub global_los: bool,
    pub god_mode: bool,
}

impl ToggleState {
    fn is_pressed(&self, action: Action) -> bool {
        match action {
            Action::FilterProblems => self.problems_only,
            Action::TogglePopupOnError => self.popup_on_error,
            Action::ToggleCheating => self.cheating,
            Action::ToggleGlobalLos => self.global_los,
            Action::ToggleGodMode => self.god_mode,
            // "Hide (F8)" reads as pressed while the console is hidden.
            Action::ToggleVisibility => !self.visible,
            _ => false,
        }
    }
}

pub(crate) struct DevConsoleView {
    context: Option<u64>,
    document: Option<u64>,
    root: Option<u64>,
    log: Option<u64>,
    actions: ActionQueue,
    visible: bool,
}

impl Default for DevConsoleView {
    fn default() -> Self {
        DevConsoleView {
            context: None,
            document: None,
            root: None,
            log: None,
            actions: Rc::new(RefCell::new(Vec::new())),
            visible: true,
        }
    }
}

impl DevConsoleView {
    pub(crate) fn is_ready(&self) -> bool {
        self.context.is_some() && self.document.is_some()
    }

    pub(crate) fn visible(&self) -> bool {
        self.visible
    }

    pub(crate) fn drain_actions(&self) -> Vec<Action> {
        self.actions.borrow_mut().drain(..).collect()
    }

    /// Create the context + document once RmlUi is up. Returns `true` the tick
    /// it is created, so the caller can backfill the console buffer.
    pub(crate) fn ensure(&mut self, interface: &NativeInterfaceRef) -> Result<bool, Error> {
        if self.is_ready() {
            return Ok(false);
        }
        let rml = interface.rml_ui();
        if !rml.is_ready()? {
            return Ok(false);
        }

        let (ctx, ok) = rml.create_context(UI_CONTEXT)?;
        if !ok {
            return Ok(false);
        }
        let geom = interface.display().get_view_geometry()?;
        let _ = rml.context_set_dimensions(ctx, geom.viewSizeX, geom.viewSizeY);

        let (doc, ok) = rml.context_create_document(ctx, "body")?;
        if !ok {
            return Ok(false);
        }
        rml.document_set_title(doc, "Developer Console")?;
        rml.document_append_to_style_sheet(doc, UI_STYLE)?;
        rml.element_set_inner_rml(doc, UI_BODY)?;
        rml.document_show(doc, None, None)?;

        self.context = Some(ctx);
        self.document = Some(doc);
        self.root = element_by_id(interface, doc, "dev-console");
        self.log = element_by_id(interface, doc, "log-container");

        self.build_toolbar(interface)?;
        Ok(true)
    }

    fn build_toolbar(&mut self, interface: &NativeInterfaceRef) -> Result<(), Error> {
        let Some(doc) = self.document else {
            return Ok(());
        };
        let Some(bar) = element_by_id(interface, doc, "toolbar") else {
            return Ok(());
        };

        let mut html = String::new();
        for action in Action::ALL {
            html.push_str(&format!(
                r#"<button id="{id}">{caption}</button>"#,
                id = action.id(),
                caption = escape_rml(action.caption()),
            ));
        }
        interface.rml_ui().element_set_inner_rml(bar, &html)?;

        // Clicks are queued: clearing the log inside the listener would free
        // the element RmlUi is dispatching to.
        for action in Action::ALL {
            let Some(button) = element_by_id(interface, doc, action.id()) else {
                continue;
            };
            let queue = self.actions.clone();
            interface
                .rml_ui()
                .element_add_event_listener(button, "click", false, move || {
                    queue.borrow_mut().push(action);
                })?;
        }
        Ok(())
    }

    pub(crate) fn set_visible(
        &mut self,
        interface: &NativeInterfaceRef,
        visible: bool,
    ) -> Result<(), Error> {
        self.visible = visible;
        if let Some(root) = self.root {
            interface
                .rml_ui()
                .element_set_class(root, "hidden", !visible)?;
        }
        Ok(())
    }

    pub(crate) fn render_log<'a>(
        &self,
        interface: &NativeInterfaceRef,
        lines: impl Iterator<Item = &'a LogLine>,
    ) -> Result<(), Error> {
        let Some(log) = self.log else {
            return Ok(());
        };
        let mut html = String::new();
        for line in lines {
            html.push_str(&format!(
                r#"<div class="log-line {class}">{text}</div>"#,
                class = line.severity.css_class(),
                text = escape_rml(&line.text),
            ));
        }
        interface.rml_ui().element_set_inner_rml(log, &html)?;
        Ok(())
    }

    /// Errors since the last clear, including lines the buffer has evicted.
    pub(crate) fn render_error_count(
        &self,
        interface: &NativeInterfaceRef,
        errors: usize,
    ) -> Result<(), Error> {
        let Some(doc) = self.document else {
            return Ok(());
        };
        let Some(label) = element_by_id(interface, doc, "error-count") else {
            return Ok(());
        };
        let text = match errors {
            0 => String::new(),
            1 => "1 error".to_string(),
            n => format!("{n} errors"),
        };
        interface.rml_ui().element_set_inner_rml(label, &text)?;
        Ok(())
    }

    pub(crate) fn render_toggles(
        &self,
        interface: &NativeInterfaceRef,
        state: ToggleState,
    ) -> Result<(), Error> {
        let Some(doc) = self.document else {
            return Ok(());
        };
        for action in Action::ALL {
            if !action.is_toggle() {
                continue;
            }
            if let Some(button) = element_by_id(interface, doc, action.id()) {
                interface.rml_ui().element_set_class(
                    button,
                    "pressed",
                    state.is_pressed(action),
                )?;
            }
        }
        Ok(())
    }

    pub(crate) fn update(&mut self, interface: &NativeInterfaceRef) -> Result<(), Error> {
        if let Some(ctx) = self.context {
            let geom = interface.display().get_view_geometry()?;
            let _ = interface
                .rml_ui()
                .context_set_dimensions(ctx, geom.viewSizeX, geom.viewSizeY);
            interface.rml_ui().context_update(ctx)?;
        }
        Ok(())
    }

    pub(crate) fn dispose(&mut self, interface: &NativeInterfaceRef) {
        let rml = interface.rml_ui();
        if let Some(doc) = self.document.take() {
            let _ = rml.document_close(doc);
        }
        if let Some(ctx) = self.context.take() {
            let _ = rml.remove_context(ctx);
        }
        self.root = None;
        self.log = None;
    }
}
