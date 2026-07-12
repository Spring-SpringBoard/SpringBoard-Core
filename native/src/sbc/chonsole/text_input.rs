//! Reusable UTF-8-safe single-line text editing state.
//!
//! Keyboard bindings deliberately live in `events.rs`; consumers choose their
//! own semantics for Tab, Up/Down, history, and completion.

#[derive(Default)]
pub(super) struct TextInput {
    value: String,
    cursor: usize,
    selection_anchor: Option<usize>,
}

impl TextInput {
    pub(super) fn value(&self) -> &str {
        &self.value
    }

    pub(super) fn cursor(&self) -> usize {
        self.cursor
    }

    pub(super) fn selection_range(&self) -> Option<(usize, usize)> {
        let anchor = self.selection_anchor?;
        (anchor != self.cursor).then(|| (anchor.min(self.cursor), anchor.max(self.cursor)))
    }

    pub(super) fn take(&mut self) -> String {
        self.cursor = 0;
        self.selection_anchor = None;
        std::mem::take(&mut self.value)
    }

    pub(super) fn set(&mut self, value: impl Into<String>) {
        self.value = value.into();
        self.cursor = self.value.len();
        self.selection_anchor = None;
    }

    pub(super) fn clear(&mut self) {
        self.value.clear();
        self.cursor = 0;
        self.selection_anchor = None;
    }

    pub(super) fn insert(&mut self, text: &str) {
        self.delete_selection();
        self.value.insert_str(self.cursor, text);
        self.cursor += text.len();
    }

    pub(super) fn backspace(&mut self) {
        if self.delete_selection() {
            return;
        }
        if let Some(previous) = previous_boundary(&self.value, self.cursor) {
            self.value.drain(previous..self.cursor);
            self.cursor = previous;
        }
    }

    pub(super) fn delete(&mut self) {
        if self.delete_selection() {
            return;
        }
        if let Some(next) = next_boundary(&self.value, self.cursor) {
            self.value.drain(self.cursor..next);
        }
    }

    pub(super) fn delete_previous_word(&mut self) {
        if self.delete_selection() {
            return;
        }
        let start = previous_word_boundary(&self.value, self.cursor);
        self.value.drain(start..self.cursor);
        self.cursor = start;
    }

    pub(super) fn delete_next_word(&mut self) {
        if self.delete_selection() {
            return;
        }
        let end = next_word_boundary(&self.value, self.cursor);
        self.value.drain(self.cursor..end);
    }

    pub(super) fn delete_to_start(&mut self) {
        if !self.delete_selection() {
            self.value.drain(0..self.cursor);
            self.cursor = 0;
        }
    }

    pub(super) fn delete_to_end(&mut self) {
        if !self.delete_selection() {
            self.value.truncate(self.cursor);
        }
    }

    pub(super) fn move_left(&mut self, extend_selection: bool) {
        if !extend_selection {
            if let Some((start, _)) = self.selection_range() {
                self.move_cursor_to(start, false);
                return;
            }
        }
        if let Some(previous) = previous_boundary(&self.value, self.cursor) {
            self.move_cursor_to(previous, extend_selection);
        } else if !extend_selection {
            self.selection_anchor = None;
        }
    }

    pub(super) fn move_right(&mut self, extend_selection: bool) {
        if !extend_selection {
            if let Some((_, end)) = self.selection_range() {
                self.move_cursor_to(end, false);
                return;
            }
        }
        if let Some(next) = next_boundary(&self.value, self.cursor) {
            self.move_cursor_to(next, extend_selection);
        } else if !extend_selection {
            self.selection_anchor = None;
        }
    }

    pub(super) fn move_previous_word(&mut self, extend_selection: bool) {
        self.move_cursor_to(
            previous_word_boundary(&self.value, self.cursor),
            extend_selection,
        );
    }

    pub(super) fn move_next_word(&mut self, extend_selection: bool) {
        self.move_cursor_to(
            next_word_boundary(&self.value, self.cursor),
            extend_selection,
        );
    }

    pub(super) fn move_home(&mut self, extend_selection: bool) {
        self.move_cursor_to(0, extend_selection);
    }

    pub(super) fn move_end(&mut self, extend_selection: bool) {
        self.move_cursor_to(self.value.len(), extend_selection);
    }

    pub(super) fn select_all(&mut self) {
        self.selection_anchor = Some(0);
        self.cursor = self.value.len();
    }

    fn move_cursor_to(&mut self, cursor: usize, extend_selection: bool) {
        if extend_selection {
            self.selection_anchor.get_or_insert(self.cursor);
            self.cursor = cursor;
            if self.selection_anchor == Some(self.cursor) {
                self.selection_anchor = None;
            }
        } else {
            self.cursor = cursor;
            self.selection_anchor = None;
        }
    }

    fn delete_selection(&mut self) -> bool {
        let Some((start, end)) = self.selection_range() else {
            return false;
        };
        self.value.drain(start..end);
        self.cursor = start;
        self.selection_anchor = None;
        true
    }
}

fn previous_boundary(text: &str, cursor: usize) -> Option<usize> {
    (cursor != 0).then(|| text[..cursor].char_indices().last().map(|(index, _)| index))?
}

fn next_boundary(text: &str, cursor: usize) -> Option<usize> {
    if cursor >= text.len() {
        return None;
    }
    text[cursor..]
        .char_indices()
        .nth(1)
        .map(|(index, _)| cursor + index)
        .or(Some(text.len()))
}

fn previous_word_boundary(text: &str, cursor: usize) -> usize {
    let mut position = cursor;
    while let Some(previous) = previous_boundary(text, position) {
        if !text[previous..position].chars().all(char::is_whitespace) {
            break;
        }
        position = previous;
    }
    while let Some(previous) = previous_boundary(text, position) {
        if text[previous..position].chars().all(char::is_whitespace) {
            break;
        }
        position = previous;
    }
    position
}

fn next_word_boundary(text: &str, cursor: usize) -> usize {
    let mut position = cursor;
    while let Some(next) = next_boundary(text, position) {
        if !text[position..next].chars().all(char::is_whitespace) {
            break;
        }
        position = next;
    }
    while let Some(next) = next_boundary(text, position) {
        if text[position..next].chars().all(char::is_whitespace) {
            break;
        }
        position = next;
    }
    position
}

#[cfg(test)]
mod tests {
    use super::TextInput;

    #[test]
    fn edits_at_cursor_and_deletes_words() {
        let mut input = TextInput::default();
        input.set("hello brave world");
        input.move_previous_word(false);
        input.delete_previous_word();
        assert_eq!(input.value(), "hello world");
        input.move_home(false);
        input.insert("say ");
        assert_eq!(input.value(), "say hello world");
        input.move_end(false);
        input.backspace();
        assert_eq!(input.value(), "say hello worl");
    }

    #[test]
    fn preserves_utf8_boundaries_and_replaces_selection() {
        let mut input = TextInput::default();
        input.set("aβc");
        input.move_left(false);
        input.move_left(false);
        input.insert("-");
        assert_eq!(input.value(), "a-βc");
        input.select_all();
        input.insert("done");
        assert_eq!(input.value(), "done");
    }
}
