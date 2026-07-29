//! The dev console's RmlUi context, document and toolbar.

use std::cell::RefCell;
use std::rc::Rc;

use spring_native::{
    prelude::{Error, NativeInterfaceRef},
    RmlDataLogRows, RmlDataTextRows, RmlDataVariable, RmlLogRow, RmlLogSeverity,
};

use crate::sbc::devconsole::actions::Action;
use crate::sbc::devconsole::log::LogLine;
use crate::sbc::rml::{self, element_by_id};

mod status;
mod text;
mod toolbar;

use text::clamp_line;

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
    status_position: Option<RmlDataVariable<'static, String>>,
    status_version: Option<RmlDataVariable<'static, String>>,
    status_metrics: Option<StatusMetricBindings>,
    status_action_disabled: [Option<RmlDataVariable<'static, bool>>; 3],
    status_history: Option<RmlDataTextRows<'static>>,
    error_count: Option<RmlDataVariable<'static, String>>,
    line_count: Option<RmlDataVariable<'static, String>>,
    log_rows: Option<RmlDataLogRows<'static>>,
    log_row_listeners_bound: usize,
    log_row_count: usize,
    /// Last history rendered into the command list. Metrics refresh regularly,
    /// but rebuilding this scroll container each frame would steal its scroll
    /// position from someone reading older edits.
    rendered_command_log: Option<Vec<HistoryCommand>>,
    hidden: Option<RmlDataVariable<'static, bool>>,
    toolbar_pressed: [Option<RmlDataVariable<'static, bool>>; 10],
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

struct StatusMetricBindings {
    performance: [StatusMetricBinding; 3],
    system: [StatusMetricBinding; 4],
}

struct StatusMetricBinding {
    value: RmlDataVariable<'static, String>,
    tones: [RmlDataVariable<'static, bool>; 4],
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
            status_position: None,
            status_version: None,
            status_metrics: None,
            status_action_disabled: [None; 3],
            status_history: None,
            error_count: None,
            line_count: None,
            log_rows: None,
            log_row_listeners_bound: 0,
            log_row_count: 0,
            rendered_command_log: None,
            hidden: None,
            toolbar_pressed: [None; 10],
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

        let data_model = rml.create_data_model(ctx, "dev_console")?;
        self.error_count = Some(data_model.bind("error_count", String::new())?);
        self.line_count = Some(data_model.bind("line_count", String::new())?);
        self.log_rows = Some(data_model.bind_log_rows("log_lines")?);
        self.hidden = Some(data_model.bind("hidden", !self.visible)?);
        for (index, action) in Action::ALL.iter().copied().enumerate() {
            self.toolbar_pressed[index] = Some(data_model.bind(action.pressed_binding(), false)?);
        }

        let (doc, ok) = rml.context_create_document(ctx, "body")?;
        if !ok {
            self.error_count = None;
            self.line_count = None;
            self.log_rows = None;
            self.hidden = None;
            self.toolbar_pressed = [None; 10];
            return Ok(false);
        }
        rml.document_set_title(doc, "Developer Console")?;
        rml.document_append_to_style_sheet(doc, UI_STYLE)?;
        rml.element_set_inner_rml(doc, UI_BODY)?;
        rml.document_show(doc, None, None)?;

        self.context = Some(ctx);
        self.document = Some(doc);
        self.log = element_by_id(interface, doc, "log-container");
        self.bind_log_mouse_up(interface)?;

        self.build_toolbar(interface)?;
        self.ensure_status(interface)?;
        // A rebuild after a reload must not silently reopen a hidden console.
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

    pub(crate) fn render_log<'a>(
        &mut self,
        interface: &NativeInterfaceRef,
        lines: impl Iterator<Item = &'a LogLine>,
        scroll_to_bottom: bool,
    ) -> Result<(), Error> {
        let Some(log) = self.log else {
            return Ok(());
        };
        let mut rows = Vec::new();
        let mut count = 0usize;
        for (index, line) in lines.enumerate() {
            count = index + 1;
            rows.push(RmlLogRow {
                text: clamp_line(&line.text).into_owned(),
                severity: match line.severity {
                    crate::sbc::devconsole::log::Severity::Info => RmlLogSeverity::Info,
                    crate::sbc::devconsole::log::Severity::Warning => RmlLogSeverity::Warning,
                    crate::sbc::devconsole::log::Severity::Error => RmlLogSeverity::Error,
                },
                selected: self.selection.contains(index),
            });
        }
        if let Some((_, end)) = self.selection.range() {
            if end >= count {
                self.selection = SelectionState::default();
            }
        }
        if let Some(log_rows) = &self.log_rows {
            log_rows.set(&rows)?;
            self.log_row_count = rows.len();
        }
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
    pub(crate) fn render_error_count(&self, errors: usize) -> Result<(), Error> {
        let text = match errors {
            0 => String::new(),
            1 => "1 error".to_string(),
            n => format!("{n} errors"),
        };
        if let Some(field) = &self.error_count {
            field.set(text)?;
        }
        Ok(())
    }

    pub(crate) fn render_line_count(&self, text: &str) -> Result<(), Error> {
        if let Some(field) = &self.line_count {
            field.set(text.to_string())?;
        }
        Ok(())
    }

    pub(crate) fn render_toggles(
        &self,
        interface: &NativeInterfaceRef,
        state: ToggleState,
    ) -> Result<(), Error> {
        let _ = interface;
        for (index, action) in Action::ALL.iter().copied().enumerate() {
            if !action.is_toggle() {
                continue;
            }
            if let Some(pressed) = &self.toolbar_pressed[index] {
                pressed.set(state.is_pressed(action))?;
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
            self.sync_log_rows(interface)?;
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
        self.status_position = None;
        self.status_version = None;
        self.status_metrics = None;
        self.status_action_disabled = [None; 3];
        self.status_history = None;
        self.error_count = None;
        self.line_count = None;
        self.log_rows = None;
        self.hidden = None;
        self.toolbar_pressed = [None; 10];
        self.log_row_listeners_bound = 0;
        self.log_row_count = 0;
        self.rendered_command_log = None;
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
        self.status_position = None;
        self.status_version = None;
        self.status_metrics = None;
        self.status_action_disabled = [None; 3];
        self.status_history = None;
        self.error_count = None;
        self.line_count = None;
        self.log_rows = None;
        self.hidden = None;
        self.toolbar_pressed = [None; 10];
        self.log_row_listeners_bound = 0;
        self.log_row_count = 0;
        if let Some(doc) = self.document.take() {
            let _ = rml.document_close(doc);
        }
        if let Some(ctx) = self.context.take() {
            let _ = rml.remove_context(ctx);
        }
        self.log = None;
    }

    fn bind_log_mouse_up(&self, interface: &NativeInterfaceRef) -> Result<(), Error> {
        let Some(log) = self.log else {
            return Ok(());
        };
        let queue = self.selection_events.clone();
        interface
            .rml_ui()
            .element_add_event_listener(log, "mouseup", false, move || {
                queue.borrow_mut().push(SelectionEvent::End);
            })
            .map(|_| ())
    }

    fn sync_log_rows(&mut self, interface: &NativeInterfaceRef) -> Result<(), Error> {
        let Some(log) = self.log else {
            return Ok(());
        };
        let rml = interface.rml_ui();
        let mut bound = self.log_row_listeners_bound;
        while bound < self.log_row_count {
            let index = bound;
            let (line, exists) = rml.element_get_child(log, index as i32)?;
            if !exists {
                break;
            }
            let queue = self.selection_events.clone();
            rml.element_add_event_listener(line, "mousedown", false, move || {
                queue.borrow_mut().push(SelectionEvent::Start(index))
            })?;
            let queue = self.selection_events.clone();
            rml.element_add_event_listener(line, "mouseover", false, move || {
                queue.borrow_mut().push(SelectionEvent::Extend(index))
            })?;
            bound += 1;
        }
        self.log_row_listeners_bound = bound;
        Ok(())
    }
}
