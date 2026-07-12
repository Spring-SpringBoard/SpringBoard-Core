//! The dev console's RmlUi context, document and toolbar.

use std::cell::RefCell;
use std::rc::Rc;

use spring_native::prelude::{Error, NativeInterfaceRef};

use crate::sbc::devconsole::actions::Action;
use crate::sbc::devconsole::log::LogLine;
use crate::sbc::rml::{self, element_by_id, escape_rml};

const UI_CONTEXT: &str = "sbc_dev_console";
const UI_BODY: &str = include_str!("ui.rml");
const UI_STYLE: &str = include_str!("ui.rcss");

pub(crate) type ActionQueue = Rc<RefCell<Vec<Action>>>;
type SelectionQueue = Rc<RefCell<Vec<SelectionEvent>>>;

#[derive(Debug, Clone, Copy)]
enum SelectionEvent {
    Start(usize),
    Extend(usize),
    End,
}

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
    selection_events: SelectionQueue,
    selection: SelectionState,
    visible: bool,
}

#[derive(Debug, Clone, Copy, Default)]
struct SelectionState {
    anchor: Option<usize>,
    extent: Option<usize>,
    dragging: bool,
}

impl SelectionState {
    fn range(self) -> Option<(usize, usize)> {
        let (a, b) = (self.anchor?, self.extent?);
        Some(if a <= b { (a, b) } else { (b, a) })
    }

    fn contains(self, index: usize) -> bool {
        self.range()
            .is_some_and(|(start, end)| index >= start && index <= end)
    }
}

impl Default for DevConsoleView {
    fn default() -> Self {
        DevConsoleView {
            context: None,
            document: None,
            root: None,
            log: None,
            actions: Rc::new(RefCell::new(Vec::new())),
            selection_events: Rc::new(RefCell::new(Vec::new())),
            selection: SelectionState::default(),
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

    /// Start hidden. `ensure` applies this when the document first binds.
    pub(crate) fn set_hidden_at_startup(&mut self) {
        self.visible = false;
    }

    /// Whether the pointer is over the console, which is what makes its keys its
    /// own rather than the panel's.
    pub(crate) fn hovered(&self, interface: &NativeInterfaceRef) -> bool {
        self.context.is_some_and(|context| {
            interface
                .rml_ui()
                .context_is_mouse_interacting(context)
                .unwrap_or(false)
        })
    }

    pub(crate) fn drain_actions(&self) -> Vec<Action> {
        self.actions.borrow_mut().drain(..).collect()
    }

    pub(crate) fn selected_range(&self) -> Option<(usize, usize)> {
        self.selection.range()
    }

    pub(crate) fn select_all(&mut self, count: usize) {
        if count == 0 {
            self.selection = SelectionState::default();
            return;
        }
        self.selection.anchor = Some(0);
        self.selection.extent = Some(count - 1);
        self.selection.dragging = false;
    }

    pub(crate) fn context_is_alive(&self, interface: &NativeInterfaceRef) -> bool {
        rml::context_is_alive(interface, UI_CONTEXT, self.context)
    }

    /// Create the context + document once RmlUi is up. Returns `true` the tick
    /// it is created, so the caller can rebuild what it owns.
    pub(crate) fn ensure(&mut self, interface: &NativeInterfaceRef) -> Result<bool, Error> {
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
        // A rebuild after a reload must not silently reopen a hidden console.
        let visible = self.visible;
        self.set_visible(interface, visible)?;
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
            let class = if action.is_toggle() {
                "toggle"
            } else {
                "command"
            };
            html.push_str(&format!(
                r#"<button id="{id}" class="{class}">{caption}</button>"#,
                id = action.id(),
                class = class,
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
        &mut self,
        interface: &NativeInterfaceRef,
        lines: impl Iterator<Item = &'a LogLine>,
        scroll_to_bottom: bool,
    ) -> Result<(), Error> {
        let Some(log) = self.log else {
            return Ok(());
        };
        let mut html = String::new();
        let mut count = 0usize;
        for (index, line) in lines.enumerate() {
            count = index + 1;
            let selected = if self.selection.contains(index) {
                " selected"
            } else {
                ""
            };
            html.push_str(&format!(
                r#"<div id="log-line-{index}" class="log-line {class}{selected}">{text}</div>"#,
                class = line.severity.css_class(),
                selected = selected,
                text = escape_rml(&line.text),
            ));
        }
        if let Some((_, end)) = self.selection.range() {
            if end >= count {
                self.selection = SelectionState::default();
            }
        }
        interface.rml_ui().element_set_inner_rml(log, &html)?;
        self.bind_log_selection(interface, count)?;
        if scroll_to_bottom {
            let _ = interface.rml_ui().element_set_scroll_top(log, 1_000_000);
        }
        Ok(())
    }

    fn bind_log_selection(
        &mut self,
        interface: &NativeInterfaceRef,
        count: usize,
    ) -> Result<(), Error> {
        let Some(doc) = self.document else {
            return Ok(());
        };
        for index in 0..count {
            let Some(line) = element_by_id(interface, doc, &format!("log-line-{index}")) else {
                continue;
            };
            let queue = self.selection_events.clone();
            interface
                .rml_ui()
                .element_add_event_listener(line, "mousedown", false, move || {
                    queue.borrow_mut().push(SelectionEvent::Start(index))
                })?;
            let queue = self.selection_events.clone();
            interface
                .rml_ui()
                .element_add_event_listener(line, "mouseover", false, move || {
                    queue.borrow_mut().push(SelectionEvent::Extend(index))
                })?;
        }
        if let Some(log) = self.log {
            let queue = self.selection_events.clone();
            interface
                .rml_ui()
                .element_add_event_listener(log, "mouseup", false, move || {
                    queue.borrow_mut().push(SelectionEvent::End);
                })?;
        }
        Ok(())
    }

    pub(crate) fn process_selection(&mut self) -> bool {
        let mut changed = false;
        for event in self.selection_events.borrow_mut().drain(..) {
            match event {
                SelectionEvent::Start(index) => {
                    self.selection.anchor = Some(index);
                    self.selection.extent = Some(index);
                    self.selection.dragging = true;
                    changed = true;
                }
                SelectionEvent::Extend(index) if self.selection.dragging => {
                    self.selection.extent = Some(index);
                    changed = true;
                }
                SelectionEvent::Extend(_) => {}
                SelectionEvent::End => self.selection.dragging = false,
            }
        }
        changed
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

    /// Drop the handles without touching them: the engine already freed them.
    pub(crate) fn forget(&mut self) {
        self.context = None;
        self.document = None;
        self.root = None;
        self.log = None;
        self.actions.borrow_mut().clear();
    }

    pub(crate) fn dispose(&mut self, interface: &NativeInterfaceRef) {
        if !self.context_is_alive(interface) {
            self.forget();
            return;
        }
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
