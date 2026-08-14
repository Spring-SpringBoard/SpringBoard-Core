use std::cell::RefCell;
use std::rc::Rc;

use spring_native::{
    prelude::{Error, NativeInterfaceRef},
    RmlDataModel, RmlDataVariable, RmlFieldType, RmlValueRef,
};

use crate::sbc::devconsole::log::{LogLine, Severity};
use crate::sbc::devconsole::log_model::LogModel;
use crate::sbc::rml::element_by_id;
use crate::sbc::rml::rows::{Row, Rows};

use super::text::clamp_line;

const MAX_LINE_CHARS: usize = 2_000;

struct LogRow {
    text: String,
    severity: Severity,
    selected: bool,
}

impl Row for LogRow {
    const FIELDS: &'static [(&'static str, RmlFieldType)] = &[
        ("text", RmlFieldType::String),
        ("info", RmlFieldType::Bool),
        ("warning", RmlFieldType::Bool),
        ("error", RmlFieldType::Bool),
        ("selected", RmlFieldType::Bool),
    ];

    fn values<'a>(&'a self, out: &mut Vec<RmlValueRef<'a>>) {
        out.push(RmlValueRef::String(&self.text));
        out.push(RmlValueRef::Bool(self.severity == Severity::Info));
        out.push(RmlValueRef::Bool(self.severity == Severity::Warning));
        out.push(RmlValueRef::Bool(self.severity == Severity::Error));
        out.push(RmlValueRef::Bool(self.selected));
    }
}

#[derive(Debug, Clone, Copy)]
enum SelectionEvent {
    Start(usize),
    Extend(usize),
    End,
}

type SelectionQueue = Rc<RefCell<Vec<SelectionEvent>>>;

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

pub(crate) struct LogPanel {
    error_count: RmlDataVariable<'static, String>,
    line_count: RmlDataVariable<'static, String>,
    log_rows: Rows<LogRow>,
    container: Option<u64>,
    selection_events: SelectionQueue,
    selection: SelectionState,
}

impl LogPanel {
    pub(crate) fn new(data_model: &RmlDataModel<'static>) -> Result<Self, Error> {
        let selection_events: SelectionQueue = Rc::new(RefCell::new(Vec::new()));
        let log_rows = Rows::<LogRow>::bind(data_model, "log_lines")?;
        let queue = selection_events.clone();
        Rows::<LogRow>::on_row(data_model, "select_from", move |index, _| {
            queue.borrow_mut().push(SelectionEvent::Start(index));
        })?;
        let queue = selection_events.clone();
        Rows::<LogRow>::on_row(data_model, "extend_to", move |index, _| {
            queue.borrow_mut().push(SelectionEvent::Extend(index));
        })?;
        Ok(LogPanel {
            error_count: data_model.bind("error_count", String::new())?,
            line_count: data_model.bind("line_count", String::new())?,
            log_rows,
            container: None,
            selection_events,
            selection: SelectionState::default(),
        })
    }

    pub(crate) fn attach(&mut self, interface: &NativeInterfaceRef, doc: u64) -> Result<(), Error> {
        self.container = element_by_id(interface, doc, "log-container");
        if let Some(log) = self.container {
            let queue = self.selection_events.clone();
            interface
                .rml_ui()
                .element_add_event_listener(log, "mouseup", false, move || {
                    queue.borrow_mut().push(SelectionEvent::End);
                })?;
        }
        Ok(())
    }

    pub(crate) fn render_if_dirty(
        &mut self,
        model: &mut LogModel,
        interface: &NativeInterfaceRef,
    ) -> Result<(), Error> {
        if !model.is_dirty() {
            return Ok(());
        }
        let scroll_to_bottom = model.take_scroll_to_bottom();
        let lines = model.rendered_lines();
        let error_count = model.error_count();
        let count_text = model.count_text();
        self.render(interface, lines.iter(), scroll_to_bottom)?;
        self.render_error_count(error_count)?;
        self.render_line_count(&count_text)?;
        model.clear_dirty();
        Ok(())
    }

    fn selected_range(&self) -> Option<(usize, usize)> {
        self.selection.range()
    }

    pub(crate) fn select_all(&mut self, model: &mut LogModel) {
        let count = model.rendered_count();
        if count == 0 {
            self.selection = SelectionState::default();
            model.mark_dirty();
            return;
        }
        self.selection.anchor = Some(0);
        self.selection.extent = Some(count - 1);
        self.selection.dragging = false;
        model.mark_dirty();
    }

    pub(crate) fn copy_selection(&self, model: &LogModel, interface: &NativeInterfaceRef) {
        let Some((start, end)) = self.selected_range() else {
            return;
        };
        let text = model
            .rendered_lines()
            .into_iter()
            .enumerate()
            .filter(|(index, _)| *index >= start && *index <= end)
            .map(|(_, line)| line.text)
            .collect::<Vec<_>>()
            .join("\n");
        if !text.is_empty() {
            let _ = interface.unsynced_ctrl().set_clipboard(&text);
        }
    }

    pub(crate) fn render<'a>(
        &mut self,
        interface: &NativeInterfaceRef,
        lines: impl Iterator<Item = &'a LogLine>,
        scroll_to_bottom: bool,
    ) -> Result<(), Error> {
        let Some(container) = self.container else {
            return Ok(());
        };

        let mut rows = Vec::new();
        let mut count = 0usize;
        for (index, line) in lines.enumerate() {
            count = index + 1;
            rows.push(LogRow {
                text: clamp_line(&line.text, MAX_LINE_CHARS).into_owned(),
                severity: line.severity,
                selected: self.selection.contains(index),
            });
        }
        if let Some((_, end)) = self.selection.range() {
            if end >= count {
                self.selection = SelectionState::default();
            }
        }
        self.log_rows.set(&rows)?;
        if scroll_to_bottom {
            let _ = interface
                .rml_ui()
                .element_set_scroll_top(container, 1_000_000);
        }
        Ok(())
    }

    pub(crate) fn process_selection(&mut self, model: &mut LogModel) {
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
        if changed {
            model.mark_dirty();
        }
    }

    pub(crate) fn render_error_count(&self, errors: usize) -> Result<(), Error> {
        let text = match errors {
            0 => String::new(),
            1 => "1 error".to_string(),
            n => format!("{n} errors"),
        };
        self.error_count.set(text)
    }

    pub(crate) fn render_line_count(&self, text: &str) -> Result<(), Error> {
        self.line_count.set(text.to_string())
    }
}
