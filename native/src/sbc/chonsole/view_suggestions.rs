//! Completion state and RmlUi rendering for Chonsole command suggestions.

use super::core::ChonsoleCore;
use super::text_input::TextInput;
use super::types::ChonsoleSuggestion;

const MAX_DESCRIPTION_CHARS: usize = 54;
const COMMAND_COLUMN_CHARS: usize = 17;

#[derive(Default)]
pub(super) struct SuggestionView {
    entries: Vec<ChonsoleSuggestion>,
    selected: Option<usize>,
}

impl SuggestionView {
    pub(super) fn reset(&mut self) {
        self.selected = None;
    }

    pub(super) fn refresh(&mut self, core: &ChonsoleCore, input: &TextInput) {
        self.entries = core.suggestions(input.value());
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
                    r#"<div class="{class}"><span class="suggestion-command">{}</span><span class="suggestion-description">{}</span></div>"#,
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
        input.set(&suggestion.command);
        self.selected = Some(index);
    }

    fn complete(&mut self, index: usize, input: &mut TextInput) {
        let Some(suggestion) = self.entries.get(index) else {
            return;
        };
        input.set(format!("{} ", suggestion.command));
        self.selected = Some(index);
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
    use super::truncate_chars;

    #[test]
    fn truncates_without_splitting_unicode() {
        assert_eq!(truncate_chars("aβc", 2), "aβ...");
        assert_eq!(truncate_chars("abc", 3), "abc");
    }
}
