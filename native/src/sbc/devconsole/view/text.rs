use std::borrow::Cow;

pub(super) fn clamp_line(text: &str, max_chars: usize) -> Cow<'_, str> {
    if text.len() <= max_chars {
        return Cow::Borrowed(text);
    }
    let mut end = max_chars;
    while !text.is_char_boundary(end) {
        end -= 1;
    }
    Cow::Owned(format!("{}… [truncated]", &text[..end]))
}

#[cfg(test)]
mod tests {
    use super::clamp_line;

    const MAX: usize = 2_000;

    #[test]
    fn short_lines_pass_through_unchanged() {
        assert_eq!(clamp_line("all good", MAX), "all good");
    }

    #[test]
    fn oversized_lines_are_cut_and_marked() {
        let huge = "x".repeat(MAX * 3);
        let clamped = clamp_line(&huge, MAX);
        assert!(clamped.len() < huge.len());
        assert!(clamped.ends_with("… [truncated]"));
    }

    #[test]
    fn truncation_respects_char_boundaries() {
        let huge = "é".repeat(MAX);
        let _ = clamp_line(&huge, MAX);
    }
}
