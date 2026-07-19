//! The dev console's line buffer and severity classification.
//!
//! The engine supplies a numeric priority for buffered and live messages. Text
//! classification remains as a fallback for messages logged at a generic level.

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

    pub(crate) fn is_problem(self) -> bool {
        !matches!(self, Severity::Info)
    }
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub(crate) struct LogLine {
    pub text: String,
    pub severity: Severity,
}

impl LogLine {
    pub(crate) fn new(text: &str, priority: Option<u32>) -> Self {
        Self {
            text: text.to_string(),
            severity: classify(text, priority),
        }
    }
}

/// "failed" counts as an error, matching the Lua console: many engine failures
/// never use the word "error".
pub(crate) fn classify(text: &str, priority: Option<u32>) -> Severity {
    let lower = text.to_lowercase();
    if priority.is_some_and(|level| level >= 50)
        || lower.contains("error")
        || lower.contains("failed")
    {
        Severity::Error
    } else if priority.is_some_and(|level| level >= 40) || lower.contains("warning") {
        Severity::Warning
    } else {
        Severity::Info
    }
}

/// The session log. It is unlimited by default; an explicit configuration may
/// retain only the newest lines, while `total` keeps the UI honest about that.
pub(crate) struct LogBuffer {
    lines: VecDeque<LogLine>,
    limit: Option<usize>,
    total: usize,
    errors: usize,
}

impl LogBuffer {
    pub(crate) fn new(limit: Option<usize>) -> Self {
        LogBuffer {
            lines: VecDeque::new(),
            limit,
            total: 0,
            errors: 0,
        }
    }

    /// Append a line, returning its severity.
    pub(crate) fn push(&mut self, text: &str, priority: Option<u32>) -> Severity {
        let line = LogLine::new(text, priority);
        let severity = line.severity;
        self.total += 1;
        if severity == Severity::Error {
            self.errors += 1;
        }
        self.lines.push_back(line);
        while self.limit.is_some_and(|limit| self.lines.len() > limit) {
            if self
                .lines
                .pop_front()
                .is_some_and(|removed| removed.severity == Severity::Error)
            {
                self.errors -= 1;
            }
        }
        severity
    }

    pub(crate) fn clear(&mut self) {
        self.lines.clear();
        self.total = 0;
        self.errors = 0;
    }

    pub(crate) fn error_count(&self) -> usize {
        self.errors
    }

    pub(crate) fn lines(&self) -> impl Iterator<Item = &LogLine> {
        self.lines.iter()
    }

    pub(crate) fn retained_count(&self) -> usize {
        self.lines.len()
    }

    pub(crate) fn total_count(&self) -> usize {
        self.total
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn severity_comes_from_the_text() {
        assert_eq!(classify("all good", None), Severity::Info);
        assert_eq!(classify("Warning: deprecated", None), Severity::Warning);
        assert_eq!(classify("ERROR: boom", None), Severity::Error);
        assert_eq!(classify("Failed to load texture", None), Severity::Error);
    }

    #[test]
    fn engine_priority_is_used_even_without_severity_words() {
        assert_eq!(classify("plain warning", Some(40)), Severity::Warning);
        assert_eq!(classify("plain failure", Some(50)), Severity::Error);
    }

    #[test]
    fn unlimited_retains_every_line() {
        let mut buffer = LogBuffer::new(None);
        for text in ["one", "two", "three"] {
            buffer.push(text, None);
        }
        let texts: Vec<_> = buffer.lines().map(|line| line.text.as_str()).collect();
        assert_eq!(texts, ["one", "two", "three"]);
        assert_eq!(buffer.retained_count(), 3);
        assert_eq!(buffer.total_count(), 3);
    }

    #[test]
    fn an_explicit_limit_reports_loss_and_drops_evicted_error_counts() {
        let mut buffer = LogBuffer::new(Some(2));
        buffer.push("error one", None);
        buffer.push("plain", None);
        buffer.push("error two", None);
        assert_eq!(buffer.error_count(), 1);
        assert_eq!(buffer.retained_count(), 2);
        assert_eq!(buffer.total_count(), 3);
    }

    #[test]
    fn clearing_resets_the_error_count() {
        let mut buffer = LogBuffer::new(None);
        buffer.push("error one", None);
        buffer.clear();
        assert_eq!(buffer.error_count(), 0);
        assert_eq!(buffer.lines().count(), 0);
        assert_eq!(buffer.total_count(), 0);
    }
}
