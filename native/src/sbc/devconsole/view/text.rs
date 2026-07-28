use std::borrow::Cow;

use super::MAX_LINE_CHARS;

pub(super) fn clamp_line(text: &str) -> Cow<'_, str> {
    if text.len() <= MAX_LINE_CHARS {
        return Cow::Borrowed(text);
    }
    let mut end = MAX_LINE_CHARS;
    while !text.is_char_boundary(end) {
        end -= 1;
    }
    Cow::Owned(format!("{}… [truncated]", &text[..end]))
}

#[cfg(test)]
mod tests {
    use super::{clamp_line, MAX_LINE_CHARS};

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
        let huge = "é".repeat(MAX_LINE_CHARS);
        let _ = clamp_line(&huge);
    }
}
