//! The dev console's line buffer and severity classification.
//!
//! The engine hands the plugin plain strings, so severity is inferred from the
//! text exactly as `dbg_dev_console_rmlui.lua` does.

use std::collections::VecDeque;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub(crate) enum Severity {
    Info,
    Warning,
    Error,
}

impl Severity {
    pub(crate) fn css_class(self) -> &'static str {
        match self {
            Severity::Info => "severity-info",
            Severity::Warning => "severity-warning",
            Severity::Error => "severity-error",
        }
    }

    fn is_problem(self) -> bool {
        !matches!(self, Severity::Info)
    }
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub(crate) struct LogLine {
    pub text: String,
    pub severity: Severity,
}

/// "failed" counts as an error, matching the Lua console: many engine failures
/// never use the word "error".
pub(crate) fn classify(text: &str) -> Severity {
    let lower = text.to_lowercase();
    if lower.contains("error") || lower.contains("failed") {
        Severity::Error
    } else if lower.contains("warning") {
        Severity::Warning
    } else {
        Severity::Info
    }
}

/// A capped ring of log lines. The console renders the tail, so the oldest
/// lines fall off the front.
pub(crate) struct LogBuffer {
    lines: VecDeque<LogLine>,
    cap: usize,
    errors: usize,
}

impl LogBuffer {
    pub(crate) fn new(cap: usize) -> Self {
        LogBuffer {
            lines: VecDeque::new(),
            cap,
            errors: 0,
        }
    }

    /// Append a line, returning its severity.
    pub(crate) fn push(&mut self, text: &str) -> Severity {
        let severity = classify(text);
        if severity == Severity::Error {
            self.errors += 1;
        }
        self.lines.push_back(LogLine {
            text: text.to_string(),
            severity,
        });
        while self.lines.len() > self.cap {
            self.lines.pop_front();
        }
        severity
    }

    pub(crate) fn clear(&mut self) {
        self.lines.clear();
        self.errors = 0;
    }

    /// Errors seen since the last clear, including lines already evicted.
    pub(crate) fn error_count(&self) -> usize {
        self.errors
    }

    pub(crate) fn visible(&self, problems_only: bool) -> impl Iterator<Item = &LogLine> {
        self.lines
            .iter()
            .filter(move |line| !problems_only || line.severity.is_problem())
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn severity_comes_from_the_text() {
        assert_eq!(classify("all good"), Severity::Info);
        assert_eq!(classify("Warning: deprecated"), Severity::Warning);
        assert_eq!(classify("ERROR: boom"), Severity::Error);
        assert_eq!(classify("Failed to load texture"), Severity::Error);
    }

    #[test]
    fn errors_outrank_warnings_in_a_line_that_has_both() {
        assert_eq!(classify("warning: load failed"), Severity::Error);
    }

    #[test]
    fn the_buffer_keeps_the_newest_lines_within_its_cap() {
        let mut buffer = LogBuffer::new(2);
        for text in ["one", "two", "three"] {
            buffer.push(text);
        }
        let texts: Vec<_> = buffer.visible(false).map(|l| l.text.as_str()).collect();
        assert_eq!(texts, ["two", "three"]);
    }

    #[test]
    fn the_problems_filter_hides_info_lines() {
        let mut buffer = LogBuffer::new(10);
        buffer.push("plain");
        buffer.push("a warning");
        buffer.push("an error");

        let all: Vec<_> = buffer.visible(false).map(|l| l.text.as_str()).collect();
        assert_eq!(all, ["plain", "a warning", "an error"]);

        let problems: Vec<_> = buffer.visible(true).map(|l| l.text.as_str()).collect();
        assert_eq!(problems, ["a warning", "an error"]);
    }

    #[test]
    fn evicted_errors_still_count() {
        let mut buffer = LogBuffer::new(1);
        buffer.push("error one");
        buffer.push("error two");
        assert_eq!(buffer.error_count(), 2);
        assert_eq!(buffer.visible(false).count(), 1);
    }

    #[test]
    fn clearing_resets_the_error_count() {
        let mut buffer = LogBuffer::new(4);
        buffer.push("error one");
        buffer.clear();
        assert_eq!(buffer.error_count(), 0);
        assert_eq!(buffer.visible(false).count(), 0);
    }
}
