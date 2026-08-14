use spring_native::prelude::NativeInterfaceRef;

use crate::sbc::devconsole::log::{LogLine, Severity};
use crate::sbc::devconsole::session::ConsoleSession;

pub(super) struct LogModel {
    session: ConsoleSession,
    problems_only: bool,
    dirty: bool,
    pin_log_bottom: bool,
    backfilled: bool,
}

impl LogModel {
    pub(super) fn new(interface: &NativeInterfaceRef) -> Self {
        Self {
            session: ConsoleSession::new(interface),
            problems_only: false,
            dirty: false,
            pin_log_bottom: false,
            backfilled: false,
        }
    }

    pub(super) fn add_line(&mut self, message: &str, priority: i32) -> Option<Severity> {
        let severity = self
            .session
            .add_live(message, priority, self.problems_only)?;
        self.mark_dirty();
        Some(severity)
    }

    pub(super) fn clear(&mut self) {
        self.session.clear();
        self.mark_dirty();
    }

    pub(super) fn toggle_problems(&mut self, interface: &NativeInterfaceRef) {
        self.problems_only = !self.problems_only;
        if self.problems_only {
            self.session.refresh_problems(interface);
        }
        self.mark_dirty();
    }

    pub(super) fn backfill_if_needed(&mut self, interface: &NativeInterfaceRef) {
        if !self.backfilled {
            self.session.backfill(interface);
            self.backfilled = true;
        }
    }

    pub(super) fn mark_dirty(&mut self) {
        self.dirty = true;
        self.pin_log_bottom = true;
    }

    pub(super) fn is_dirty(&self) -> bool {
        self.dirty
    }

    pub(super) fn clear_dirty(&mut self) {
        self.dirty = false;
    }

    pub(super) fn take_scroll_to_bottom(&mut self) -> bool {
        std::mem::take(&mut self.pin_log_bottom)
    }

    pub(super) fn problems_only(&self) -> bool {
        self.problems_only
    }

    pub(super) fn rendered_lines(&self) -> Vec<LogLine> {
        self.session
            .rendered_lines(self.problems_only)
            .into_iter()
            .cloned()
            .collect()
    }

    pub(super) fn rendered_count(&self) -> usize {
        self.session.rendered_count(self.problems_only)
    }

    pub(super) fn error_count(&self) -> usize {
        self.session.error_count(self.problems_only)
    }

    pub(super) fn count_text(&self) -> String {
        self.session.count_text(self.problems_only)
    }
}
