//! The dev console's RmlUi context, document and toolbar.

use std::cell::RefCell;
use std::rc::Rc;

use spring_native::prelude::{Error, NativeInterfaceRef};

use crate::sbc::devconsole::actions::Action;
use crate::sbc::devconsole::log::LogLine;
use crate::sbc::rml::{self, element_by_id, escape_rml};

/// A single console line longer than this is truncated before rendering. RmlUi
/// fails to instance a text element past a certain size; an oversized engine
/// line (a stack dump, a serialized blob) must not be able to break the log.
const MAX_LINE_CHARS: usize = 2_000;

const UI_CONTEXT: &str = "sbc_dev_console";
const UI_BODY: &str = include_str!("ui.rml");
const STATUS_CONTEXT: &str = "sbc_editor_status";
const STATUS_BODY: &str = include_str!("status.rml");
const UI_STYLE: &str = concat!(
    include_str!("../theme/base.rcss"),
    include_str!("../theme/controls.rcss"),
    include_str!("../theme/scrollbars.rcss"),
    include_str!("../theme/developer_console.rcss"),
);

pub(crate) type ActionQueue = Rc<RefCell<Vec<Action>>>;
type SelectionQueue = Rc<RefCell<Vec<SelectionEvent>>>;

#[derive(Debug, Clone, Copy)]
pub(crate) enum StatusAction {
    Undo,
    Redo,
    ClearHistory,
}

/// One row in the undo/redo history strip. `undone` is the visual undo cursor:
/// it stays in the list but is muted until Redo restores it.
#[derive(Clone, Debug, PartialEq, Eq)]
pub(crate) struct HistoryCommand {
    pub caption: String,
    pub undone: bool,
}

type StatusActionQueue = Rc<RefCell<Vec<StatusAction>>>;

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
    /// Kept in a separate context from the F8 console so it has its own
    /// viewport-sized document and remains visible when the console is hidden.
    status_context: Option<u64>,
    status_document: Option<u64>,
    /// Last history rendered into the command list. Metrics refresh regularly,
    /// but rebuilding this scroll container each frame would steal its scroll
    /// position from someone reading older edits.
    rendered_command_log: Option<Vec<HistoryCommand>>,
    root: Option<u64>,
    log: Option<u64>,
    actions: ActionQueue,
    status_actions: StatusActionQueue,
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
            status_context: None,
            status_document: None,
            rendered_command_log: None,
            root: None,
            log: None,
            actions: Rc::new(RefCell::new(Vec::new())),
            status_actions: Rc::new(RefCell::new(Vec::new())),
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

    pub(crate) fn drain_status_actions(&self) -> Vec<StatusAction> {
        self.status_actions.borrow_mut().drain(..).collect()
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
                self.ensure_status(interface)?;
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
        self.ensure_status(interface)?;
        // A rebuild after a reload must not silently reopen a hidden console.
        let visible = self.visible;
        self.set_visible(interface, visible)?;
        Ok(true)
    }

    pub(crate) fn render_status(
        &mut self,
        interface: &NativeInterfaceRef,
        position: &str,
        performance: &str,
        system: &str,
        version: &str,
        commands: &[HistoryCommand],
    ) -> Result<(), Error> {
        let Some(doc) = self.status_document else {
            return Ok(());
        };
        for (id, text) in [("status-position", position), ("status-version", version)] {
            if let Some(element) = element_by_id(interface, doc, id) {
                interface
                    .rml_ui()
                    .element_set_inner_rml(element, &escape_rml(text))?;
            }
        }
        // These strings are built exclusively from numeric measurements and
        // fixed labels in `manager`; render their metric spans intentionally so
        // CSS can give each cell a stable width and a semantic colour.
        for (id, markup) in [
            ("status-performance", performance),
            ("status-system", system),
        ] {
            if let Some(element) = element_by_id(interface, doc, id) {
                interface.rml_ui().element_set_inner_rml(element, markup)?;
            }
        }
        let can_undo = commands.iter().any(|command| !command.undone);
        let can_redo = commands.iter().any(|command| command.undone);
        let can_clear = can_undo || can_redo;
        for (id, enabled) in [
            ("status-undo", can_undo),
            ("status-redo", can_redo),
            ("status-clear", can_clear),
        ] {
            if let Some(button) = element_by_id(interface, doc, id) {
                interface
                    .rml_ui()
                    .element_set_class(button, "disabled", !enabled)?;
            }
        }
        if self.rendered_command_log.as_deref() != Some(commands) {
            if let Some(list) = element_by_id(interface, doc, "command-list") {
                let html: String = commands
                    .iter()
                    .rev()
                    .take(12)
                    .rev()
                    .map(|command| {
                        let class = if command.undone {
                            "command-item undone"
                        } else {
                            "command-item"
                        };
                        format!(
                            r#"<div class="{class}">{}</div>"#,
                            escape_rml(&command.caption)
                        )
                    })
                    .collect();
                interface.rml_ui().element_set_inner_rml(list, &html)?;
                // A newly executed edit should be visible, but no periodic
                // metric update is allowed to reset a manual scroll.
                let _ = interface.rml_ui().element_set_scroll_top(list, 1_000_000);
            }
            self.rendered_command_log = Some(commands.to_vec());
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
                text = defuse_data_brackets(&escape_rml(&clamp_line(&line.text))),
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

    pub(crate) fn render_line_count(
        &self,
        interface: &NativeInterfaceRef,
        text: &str,
    ) -> Result<(), Error> {
        let Some(doc) = self.document else {
            return Ok(());
        };
        let Some(label) = element_by_id(interface, doc, "line-count") else {
            return Ok(());
        };
        interface
            .rml_ui()
            .element_set_inner_rml(label, &escape_rml(text))?;
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
        if let Some(context) = self.status_context {
            let geometry = interface.display().get_view_geometry()?;
            let _ = interface.rml_ui().context_set_dimensions(
                context,
                geometry.viewSizeX,
                geometry.viewSizeY,
            );
            interface.rml_ui().context_update(context)?;
        }
        Ok(())
    }

    /// Drop the handles without touching them: the engine already freed them.
    pub(crate) fn forget(&mut self) {
        self.context = None;
        self.document = None;
        self.status_context = None;
        self.status_document = None;
        self.rendered_command_log = None;
        self.root = None;
        self.log = None;
        self.actions.borrow_mut().clear();
        self.status_actions.borrow_mut().clear();
    }

    pub(crate) fn dispose(&mut self, interface: &NativeInterfaceRef) {
        if !self.context_is_alive(interface) {
            self.forget();
            return;
        }
        let rml = interface.rml_ui();
        if let Some(document) = self.status_document.take() {
            let _ = rml.document_close(document);
        }
        if let Some(context) = self.status_context.take() {
            let _ = rml.remove_context(context);
        }
        if let Some(doc) = self.document.take() {
            let _ = rml.document_close(doc);
        }
        if let Some(ctx) = self.context.take() {
            let _ = rml.remove_context(ctx);
        }
        self.root = None;
        self.log = None;
    }

    /// The scen_edit-style status bar intentionally has a dedicated RmlUi
    /// context. A document has one layout root in this engine; putting it next
    /// to the F8 console made the strip depend on that console's containing
    /// block and could leave it unpainted. Its own context makes it a genuine
    /// screen-edge surface and lets it stay up while F8 hides the console.
    fn ensure_status(&mut self, interface: &NativeInterfaceRef) -> Result<(), Error> {
        if let Some(context) = self.status_context {
            if rml::context_is_alive(interface, STATUS_CONTEXT, Some(context)) {
                return Ok(());
            }
            self.status_context = None;
            self.status_document = None;
            self.rendered_command_log = None;
        }

        let rml = interface.rml_ui();
        let (context, created) = rml.create_context(STATUS_CONTEXT)?;
        if !created {
            return Ok(());
        }
        let geometry = interface.display().get_view_geometry()?;
        let _ = rml.context_set_dimensions(context, geometry.viewSizeX, geometry.viewSizeY);
        let (document, created) = rml.context_create_document(context, "body")?;
        if !created {
            let _ = rml.remove_context(context);
            return Ok(());
        }
        rml.document_set_title(document, "Editor status")?;
        rml.document_append_to_style_sheet(document, UI_STYLE)?;
        rml.element_set_inner_rml(document, STATUS_BODY)?;
        rml.document_show(document, None, None)?;
        self.status_context = Some(context);
        self.status_document = Some(document);
        self.rendered_command_log = None;
        self.bind_status_actions(interface)
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
                "toggle theme-toggle"
            } else {
                "command"
            };
            let caption = escape_rml(action.caption());
            let content = if action.is_toggle() {
                format!(
                    r#"<span class="toggle-label">{caption}</span><span class="theme-toggle-switch"><span class="theme-toggle-thumb"></span></span>"#
                )
            } else {
                // RmlUi drops a raw text node inside a flex button. Commands
                // need the same explicit text element as toggle labels.
                format!(r#"<span class="command-label">{caption}</span>"#)
            };
            html.push_str(&format!(
                r#"<button id="{id}" class="{class}">{content}</button>"#,
                id = action.id(),
                class = class,
                content = content,
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

    fn bind_status_actions(&self, interface: &NativeInterfaceRef) -> Result<(), Error> {
        let Some(doc) = self.status_document else {
            return Ok(());
        };
        for (id, action) in [
            ("status-undo", StatusAction::Undo),
            ("status-redo", StatusAction::Redo),
            ("status-clear", StatusAction::ClearHistory),
        ] {
            let Some(button) = element_by_id(interface, doc, id) else {
                continue;
            };
            let queue = self.status_actions.clone();
            interface
                .rml_ui()
                .element_add_event_listener(button, "click", false, move || {
                    queue.borrow_mut().push(action);
                })?;
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
}

/// RmlUi reads `{{ … }}` in element text as a data-binding expression and logs
/// "Failed to instance text element" on any malformed one (a stray `}}`, a lone
/// `}` inside brackets). Engine stat dumps are full of such braces
/// (`{{863.446, 0.402}}`), and one bad line fails the whole log render, spamming
/// a warning every frame. A zero-width space after every brace breaks the
/// `{{`/`}}` adjacency the parser keys on, so no text is ever treated as an
/// expression. The glyphs render identically and copy uses the untouched buffer.
fn defuse_data_brackets(text: &str) -> std::borrow::Cow<'_, str> {
    if !text.contains(['{', '}']) {
        return std::borrow::Cow::Borrowed(text);
    }
    std::borrow::Cow::Owned(text.replace('{', "{\u{200b}").replace('}', "}\u{200b}"))
}

/// Truncate an over-long line on a char boundary, appending an ellipsis note so
/// the reader knows it was cut. The full text stays in the buffer for copy.
fn clamp_line(text: &str) -> std::borrow::Cow<'_, str> {
    if text.len() <= MAX_LINE_CHARS {
        return std::borrow::Cow::Borrowed(text);
    }
    let mut end = MAX_LINE_CHARS;
    while !text.is_char_boundary(end) {
        end -= 1;
    }
    std::borrow::Cow::Owned(format!("{}… [truncated]", &text[..end]))
}

#[cfg(test)]
mod tests {
    use super::{clamp_line, defuse_data_brackets, MAX_LINE_CHARS};

    #[test]
    fn brace_free_text_is_untouched() {
        assert_eq!(defuse_data_brackets("no braces here"), "no braces here");
    }

    #[test]
    fn adjacent_braces_are_split_by_a_zero_width_space() {
        // The engine stat pattern that tripped RmlUi's data parser.
        let out = defuse_data_brackets("time={{863.446, 0.402}}ms");
        assert!(!out.contains("{{"), "no `{{{{` may survive: {out:?}");
        assert!(!out.contains("}}"), "no `}}}}` may survive: {out:?}");
        // The visible glyphs are unchanged once the zero-width spaces are gone.
        assert_eq!(out.replace('\u{200b}', ""), "time={{863.446, 0.402}}ms");
    }

    #[test]
    fn short_lines_pass_through_unchanged() {
        assert_eq!(clamp_line("all good"), "all good");
    }

    #[test]
    fn oversized_lines_are_cut_and_marked() {
        let huge = "x".repeat(MAX_LINE_CHARS * 3);
        let clamped = clamp_line(&huge);
        assert!(clamped.len() < huge.len());
        assert!(clamped.ends_with("… [truncated]"));
    }

    #[test]
    fn truncation_respects_char_boundaries() {
        // A multi-byte char straddling the cut must not panic.
        let huge = "é".repeat(MAX_LINE_CHARS);
        let _ = clamp_line(&huge);
    }
}
