//! Session retention and engine-buffer refresh for the developer console.

use spring_native::prelude::NativeInterfaceRef;

use crate::sbc::devconsole::log::{LogBuffer, LogLine, Severity};

const MAX_LINES_CONFIG: &str = "SpringBoardDevConsoleMaxLines";
const MIN_CONFIGURED_LINES: usize = 2_000;

pub(crate) struct ConsoleSession {
    all: LogBuffer,
    problems: Vec<LogLine>,
    problem_source_lines: usize,
}

impl ConsoleSession {
    pub(crate) fn new(interface: &NativeInterfaceRef) -> Self {
        Self {
            all: LogBuffer::new(configured_line_limit(interface)),
            problems: Vec::new(),
            problem_source_lines: 0,
        }
    }

    pub(crate) fn backfill(&mut self, interface: &NativeInterfaceRef) {
        let Ok(entries) = interface.messages().get_console_entries(0) else {
            return;
        };
        for entry in entries {
            if show_console_line(&entry.text) {
                self.all.push(entry.text.trim_end(), Some(entry.priority));
            }
        }
    }

    pub(crate) fn add_live(
        &mut self,
        message: &str,
        priority: i32,
        problems_visible: bool,
    ) -> Option<Severity> {
        if !show_console_line(message) {
            return None;
        }
        let text = message.trim_end();
        let priority = u32::try_from(priority).ok();
        let severity = self.all.push(text, priority);
        if problems_visible {
            self.problem_source_lines += 1;
            if severity.is_problem() {
                self.problems.push(LogLine::new(text, priority));
            }
        }
        Some(severity)
    }

    /// Rebuild from the engine rather than filtering the locally retained tail.
    pub(crate) fn refresh_problems(&mut self, interface: &NativeInterfaceRef) {
        self.problems = self
            .all
            .lines()
            .filter(|line| line.severity.is_problem())
            .cloned()
            .collect();
        self.problem_source_lines = self.all.total_count();

        let Ok(entries) = interface.messages().get_console_entries(0) else {
            return;
        };
        let engine_source_lines = entries
            .iter()
            .filter(|entry| show_console_line(&entry.text))
            .count();
        self.problem_source_lines = self.problem_source_lines.max(engine_source_lines);
        for line in entries
            .into_iter()
            .filter(|entry| show_console_line(&entry.text))
            .map(|entry| LogLine::new(entry.text.trim_end(), Some(entry.priority)))
            .filter(|line| line.severity.is_problem())
        {
            if !self.problems.contains(&line) {
                self.problems.push(line);
            }
        }
    }

    pub(crate) fn clear(&mut self) {
        self.all.clear();
        self.problems.clear();
        self.problem_source_lines = 0;
    }

    pub(crate) fn visible_lines(&self, problems_only: bool) -> Vec<&LogLine> {
        if problems_only {
            self.problems.iter().collect()
        } else {
            self.all.lines().collect()
        }
    }

    pub(crate) fn visible_count(&self, problems_only: bool) -> usize {
        if problems_only {
            self.problems.len()
        } else {
            self.all.retained_count()
        }
    }

    pub(crate) fn error_count(&self, problems_only: bool) -> usize {
        if problems_only {
            self.problems
                .iter()
                .filter(|line| line.severity == Severity::Error)
                .count()
        } else {
            self.all.error_count()
        }
    }

    pub(crate) fn count_text(&self, problems_only: bool) -> String {
        if problems_only {
            return format!(
                "Showing {} problems from {} engine lines",
                self.problems.len(),
                self.problem_source_lines
            );
        }
        format!(
            "Showing {} of {} lines",
            self.all.retained_count(),
            self.all.total_count()
        )
    }
}

/// `get_game_mod_info` reports these hashes through the engine console. They
/// are archive bookkeeping, not developer diagnostics, and repeat whenever a
/// caller refreshes mod metadata.
fn show_console_line(message: &str) -> bool {
    !message.contains("[CAS::GASCB] Archive file=")
}

/// Zero or an unset value keeps every session line. A finite value is clamped
/// to a useful floor so a typo cannot silently recreate a tiny console.
fn configured_line_limit(interface: &NativeInterfaceRef) -> Option<usize> {
    let (configured, _) = interface
        .config()
        .get_config_int(MAX_LINES_CONFIG, Some(0))
        .ok()?;
    usize::try_from(configured)
        .ok()
        .filter(|limit| *limit > 0)
        .map(|limit| limit.max(MIN_CONFIGURED_LINES))
}
