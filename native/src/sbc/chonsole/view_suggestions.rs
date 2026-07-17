//! Completion state and RmlUi rendering for Chonsole command suggestions.

use super::core::ChonsoleCore;
use super::text_input::TextInput;
use super::types::ChonsoleSuggestion;

// The RmlUi columns clip at their actual geometry. These limits only add an
// explicit ellipsis for genuinely long entries, instead of throwing away
// usable command and description space before RmlUi lays them out.
const MAX_DESCRIPTION_CHARS: usize = 72;
const COMMAND_COLUMN_CHARS: usize = 36;

#[derive(Default)]
pub(super) struct SuggestionView {
    entries: Vec<ChonsoleSuggestion>,
    selected: Option<usize>,
    query: Option<String>,
}

impl SuggestionView {
    pub(super) fn reset(&mut self) {
        self.selected = None;
        self.query = None;
    }

    pub(super) fn refresh(&mut self, core: &ChonsoleCore, input: &TextInput) {
        let query = self.query.as_deref().unwrap_or(input.value());
        self.entries = core.suggestions(query);
        if self
            .selected
            .is_some_and(|index| index >= self.entries.len())
        {
            self.selected = None;
        }
    }

    pub(super) fn complete_first(&mut self, core: &ChonsoleCore, input: &mut TextInput) {
        self.refresh(core, input);
        self.complete(self.selected.unwrap_or(0), input);
    }

    pub(super) fn select_previous(
        &mut self,
        core: &ChonsoleCore,
        input: &mut TextInput,
        steps: usize,
    ) -> bool {
        self.refresh(core, input);
        if !input.value().starts_with('/') || self.entries.is_empty() {
            return false;
        }
        let current = self.selected.unwrap_or(0);
        self.apply(current.saturating_sub(steps.max(1)), input);
        true
    }

    pub(super) fn select_next(
        &mut self,
        core: &ChonsoleCore,
        input: &mut TextInput,
        steps: usize,
    ) -> bool {
        self.refresh(core, input);
        if !input.value().starts_with('/') || self.entries.is_empty() {
            return false;
        }
        let current = self.selected.unwrap_or(usize::MAX);
        let index = if current == usize::MAX {
            0
        } else {
            (current + steps.max(1)).min(self.entries.len() - 1)
        };
        self.apply(index, input);
        true
    }

    pub(super) fn select(
        &mut self,
        core: &ChonsoleCore,
        input: &mut TextInput,
        index: usize,
    ) -> bool {
        self.refresh(core, input);
        if !input.value().starts_with('/') || index >= self.entries.len() {
            return false;
        }
        self.apply(index, input);
        true
    }

    pub(super) fn len(&self) -> usize {
        self.entries.len()
    }

    /// The full text for the fixed detail strip. Hover takes precedence over a
    /// keyboard selection, and leaving a row falls back to that selection.
    pub(super) fn detail(&self, hovered: Option<usize>) -> Option<(&str, &str)> {
        hovered
            .or(self.selected)
            .and_then(|index| self.entries.get(index))
            .filter(|suggestion| !suggestion.description.is_empty())
            .map(|suggestion| (suggestion.command.as_str(), suggestion.description.as_str()))
    }

    pub(super) fn render(&self) -> String {
        self.entries
            .iter()
            .enumerate()
            .map(|(index, suggestion)| {
                let command = truncate_chars(&suggestion.command, COMMAND_COLUMN_CHARS);
                let description = truncate_chars(&suggestion.description, MAX_DESCRIPTION_CHARS);
                let class = if self.selected == Some(index) {
                    "suggestion selected-suggestion"
                } else {
                    "suggestion"
                };
                format!(
                    r#"<div id="suggestion-{index}" class="{class}"><span class="suggestion-command">{}</span><span class="suggestion-description">{}</span></div>"#,
                    escape_rml(&command),
                    escape_rml(&description)
                )
            })
            .collect::<Vec<_>>()
            .join("")
    }

    fn apply(&mut self, index: usize, input: &mut TextInput) {
        let Some(suggestion) = self.entries.get(index) else {
            return;
        };
        self.query.get_or_insert_with(|| input.value().to_string());
        input.set(&suggestion.command);
        self.selected = Some(index);
    }

    fn complete(&mut self, index: usize, input: &mut TextInput) {
        let Some(suggestion) = self.entries.get(index) else {
            return;
        };
        input.set(format!("{} ", suggestion.command));
        self.reset();
    }
}

pub(super) fn escape_rml(text: &str) -> String {
    text.replace('&', "&amp;")
        .replace('<', "&lt;")
        .replace('>', "&gt;")
}

fn truncate_chars(text: &str, max_chars: usize) -> String {
    let mut chars = text.chars();
    let truncated = chars.by_ref().take(max_chars).collect::<String>();
    if chars.next().is_some() {
        format!("{truncated}...")
    } else {
        truncated
    }
}

#[cfg(test)]
mod tests {
    use super::{truncate_chars, SuggestionView};
    use crate::sbc::chonsole::core::ChonsoleCore;
    use crate::sbc::chonsole::text_input::TextInput;

    #[test]
    fn truncates_without_splitting_unicode() {
        assert_eq!(truncate_chars("aβc", 2), "aβ...");
        assert_eq!(truncate_chars("abc", 3), "abc");
    }

    #[test]
    fn next_selection_keeps_the_original_suggestion_list() {
        let core = ChonsoleCore::default();
        let mut input = TextInput::default();
        input.set("/h");
        let mut suggestions = SuggestionView::default();

        assert!(suggestions.select_next(&core, &mut input, 1));
        let entries = suggestions.entries.clone();
        assert!(entries.len() > 1);
        assert_eq!(suggestions.selected, Some(0));

        assert!(suggestions.select_next(&core, &mut input, 1));
        assert_eq!(suggestions.entries, entries);
        assert_eq!(suggestions.selected, Some(1));
        assert_eq!(input.value(), entries[1].command);
    }

    #[test]
    fn selecting_a_rendered_suggestion_keeps_the_match_list() {
        let core = ChonsoleCore::default();
        let mut input = TextInput::default();
        input.set("/h");
        let mut suggestions = SuggestionView::default();

        suggestions.refresh(&core, &input);
        let entries = suggestions.entries.clone();
        assert!(suggestions.select(&core, &mut input, 1));
        assert_eq!(suggestions.entries, entries);
        assert_eq!(suggestions.selected, Some(1));
        assert_eq!(input.value(), entries[1].command);
    }

    #[test]
    fn detail_prefers_hovered_suggestion_over_keyboard_selection() {
        let core = ChonsoleCore::default();
        let mut input = TextInput::default();
        input.set("/h");
        let mut suggestions = SuggestionView::default();

        assert!(suggestions.select_next(&core, &mut input, 1));
        let selected = suggestions.detail(None).unwrap();
        let hovered = suggestions.detail(Some(1)).unwrap();
        assert_ne!(selected.0, hovered.0);
        assert_eq!(suggestions.detail(Some(1)), Some(hovered));
    }
}
