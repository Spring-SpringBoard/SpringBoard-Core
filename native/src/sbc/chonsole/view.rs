use spring_native::prelude::{Error, NativeInterfaceRef};

use super::core::ChonsoleCore;
use super::types::{ChonsoleLine, ChonsoleLineKind, ChonsoleResponse, ChonsoleSuggestion};
use crate::sbc::rml::{self, element_by_id};

const MAX_UI_LINES: usize = 200;
const UI_CONTEXT: &str = "sbc_native_chonsole";
const UI_BODY: &str = include_str!("ui.rml");
const UI_STYLE: &str = include_str!("ui.rcss");
const MAX_SUGGESTION_DESCRIPTION_CHARS: usize = 54;
const SUGGESTION_COMMAND_COLUMN_CHARS: usize = 17;

pub(super) struct ChonsoleView {
    context: Option<u64>,
    document: Option<u64>,
    root: Option<u64>,
    lines: Option<u64>,
    visible: bool,
    input: String,
    cursor: usize,
    selection_anchor: Option<usize>,
    output: Vec<ChonsoleLine>,
    suggestions: Vec<ChonsoleSuggestion>,
    selected_suggestion: Option<usize>,
    mouse_captured: bool,
    rml_enabled: bool,
}

impl Default for ChonsoleView {
    fn default() -> Self {
        ChonsoleView {
            context: None,
            document: None,
            root: None,
            lines: None,
            visible: false,
            input: String::new(),
            cursor: 0,
            selection_anchor: None,
            output: Vec::new(),
            suggestions: Vec::new(),
            selected_suggestion: None,
            mouse_captured: false,
            rml_enabled: true,
        }
    }
}

impl ChonsoleView {
    pub(super) fn context_is_alive(&self, interface: &NativeInterfaceRef) -> bool {
        rml::context_is_alive(interface, UI_CONTEXT, self.context)
    }

    /// Drop the handles without touching them: the engine already freed them.
    fn forget(&mut self) {
        self.context = None;
        self.document = None;
        self.root = None;
        self.lines = None;
    }

    pub(super) fn ensure(&mut self, interface: &NativeInterfaceRef) -> Result<(), Error> {
        if !self.rml_enabled {
            return Ok(());
        }
        if self.context.is_some() && self.document.is_some() {
            if self.context_is_alive(interface) {
                return Ok(());
            }
            // `luaui reload` destroyed every RmlUi context, ours included.
            // Drop the handles untouched and build a fresh document below.
            self.forget();
        }
        let rml = interface.rml_ui();
        if !rml.is_ready()? {
            return Ok(());
        }
        let (context, ok) = rml.create_context(UI_CONTEXT)?;
        if !ok {
            return Ok(());
        }
        let geom = interface.display().get_view_geometry()?;
        let _ = rml.context_set_dimensions(context, geom.viewSizeX, geom.viewSizeY);
        let (document, ok) = rml.context_create_document(context, "body")?;
        if !ok {
            return Ok(());
        }
        let visible = self.visible;
        rml.document_set_title(document, "Native Chonsole")?;
        rml.document_append_to_style_sheet(document, UI_STYLE)?;
        rml.element_set_inner_rml(document, UI_BODY)?;
        rml.document_show(document, None, None)?;

        self.context = Some(context);
        self.document = Some(document);
        self.root = element_by_id(interface, document, "native-chonsole");
        self.lines = element_by_id(interface, document, "native-chonsole-lines");
        self.output.push(ChonsoleLine {
            kind: ChonsoleLineKind::Output,
            text: "native chonsole ready. F10 toggles, /help lists commands.".to_string(),
        });
        self.set_visible(interface, visible)?;
        self.refresh(interface, &ChonsoleCore::default())?;
        Ok(())
    }

    pub(super) fn update(&mut self, interface: &NativeInterfaceRef) -> Result<(), Error> {
        if let Some(context) = self.context {
            let geom = interface.display().get_view_geometry()?;
            let _ =
                interface
                    .rml_ui()
                    .context_set_dimensions(context, geom.viewSizeX, geom.viewSizeY);
            interface.rml_ui().context_update(context)?;
        }
        Ok(())
    }

    pub(super) fn draw_screen(&mut self, interface: &NativeInterfaceRef) -> Result<(), Error> {
        if self.visible && self.context.is_none() {
            let gfx = interface.gfx();
            let _ = gfx.begin_text(false);
            let input = if self.input.is_empty() {
                ">"
            } else {
                self.input.as_str()
            };
            let _ = gfx.text("Native chonsole (Rust)", 60.0, 110.0, 22.0, "o");
            let _ = gfx.text("Enter captured by native plugin", 60.0, 138.0, 16.0, "o");
            let _ = gfx.text(input, 60.0, 166.0, 18.0, "o");
            let _ = gfx.end_text();
        }
        // The engine renders every RmlUi context itself in `RmlGui::RenderFrame`;
        // a plugin calling `context_render` here submits geometry outside that
        // frame, where it is silently dropped. So there is nothing to do for the
        // RmlUi path — only the gfx-text fallback above draws.
        Ok(())
    }

    pub(super) fn dispose(&mut self, interface: &NativeInterfaceRef) {
        if !self.context_is_alive(interface) {
            self.forget();
            return;
        }
        let rml = interface.rml_ui();
        if let Some(document) = self.document.take() {
            let _ = rml.document_close(document);
        }
        if let Some(context) = self.context.take() {
            let _ = rml.remove_context(context);
        }
        self.root = None;
        self.lines = None;
        self.mouse_captured = false;
    }

    pub(super) fn visible(&self) -> bool {
        self.visible
    }

    pub(super) fn toggle(&mut self, interface: &NativeInterfaceRef) -> Result<(), Error> {
        self.set_visible(interface, !self.visible)
    }

    pub(super) fn set_visible(
        &mut self,
        interface: &NativeInterfaceRef,
        visible: bool,
    ) -> Result<(), Error> {
        self.visible = visible;
        let Some(document) = self.document else {
            return Ok(());
        };
        if visible {
            interface.rml_ui().document_show(document, None, None)?;
            if let Some(context) = self.context {
                let _ = interface
                    .rml_ui()
                    .context_enable_mouse_cursor(context, true);
                let _ = interface
                    .rml_ui()
                    .context_pull_document_to_front(context, document);
            }
        } else {
            interface.rml_ui().document_hide(document)?;
            self.mouse_captured = false;
            if let Some(context) = self.context {
                let _ = interface.rml_ui().context_process_mouse_leave(context);
            }
        }
        Ok(())
    }

    pub(super) fn clear(&mut self) {
        self.output.clear();
    }

    pub(super) fn apply_response(&mut self, response: &ChonsoleResponse, core: &ChonsoleCore) {
        self.output.extend(response.lines.iter().cloned());
        if self.output.len() > MAX_UI_LINES {
            let keep_from = self.output.len() - MAX_UI_LINES;
            self.output.drain(0..keep_from);
        }
        self.refresh_suggestions(core);
    }

    pub(super) fn input(&self) -> &str {
        &self.input
    }

    pub(super) fn take_input(&mut self) -> String {
        self.cursor = 0;
        self.selection_anchor = None;
        self.selected_suggestion = None;
        std::mem::take(&mut self.input)
    }

    pub(super) fn set_input(&mut self, input: impl Into<String>) {
        self.input = input.into();
        self.cursor = self.input.len();
        self.selection_anchor = None;
        self.selected_suggestion = None;
    }

    pub(super) fn clear_input(&mut self) {
        self.input.clear();
        self.cursor = 0;
        self.selection_anchor = None;
        self.selected_suggestion = None;
    }

    pub(super) fn push_input(&mut self, text: &str) {
        self.delete_selection();
        self.input.insert_str(self.cursor, text);
        self.cursor += text.len();
        self.selected_suggestion = None;
    }

    pub(super) fn pop_input(&mut self) {
        if self.delete_selection() {
            return;
        }
        if let Some(prev) = prev_boundary(&self.input, self.cursor) {
            self.input.drain(prev..self.cursor);
            self.cursor = prev;
        }
        self.selected_suggestion = None;
    }

    pub(super) fn delete_input(&mut self) {
        if self.delete_selection() {
            return;
        }
        if let Some(next) = next_boundary(&self.input, self.cursor) {
            self.input.drain(self.cursor..next);
        }
        self.selected_suggestion = None;
    }

    pub(super) fn delete_prev_word(&mut self) {
        if self.delete_selection() {
            return;
        }
        let start = prev_word_boundary(&self.input, self.cursor);
        self.input.drain(start..self.cursor);
        self.cursor = start;
        self.selected_suggestion = None;
    }

    pub(super) fn delete_next_word(&mut self) {
        if self.delete_selection() {
            return;
        }
        let end = next_word_boundary(&self.input, self.cursor);
        self.input.drain(self.cursor..end);
        self.selected_suggestion = None;
    }

    pub(super) fn delete_to_start(&mut self) {
        if self.delete_selection() {
            return;
        }
        self.input.drain(0..self.cursor);
        self.cursor = 0;
        self.selected_suggestion = None;
    }

    pub(super) fn delete_to_end(&mut self) {
        if self.delete_selection() {
            return;
        }
        self.input.truncate(self.cursor);
        self.selected_suggestion = None;
    }

    pub(super) fn move_left(&mut self, extend_selection: bool) {
        if !extend_selection {
            if let Some((start, _)) = self.selection_range() {
                self.move_cursor_to(start, false);
                return;
            }
        }
        if let Some(prev) = prev_boundary(&self.input, self.cursor) {
            self.move_cursor_to(prev, extend_selection);
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
        if let Some(next) = next_boundary(&self.input, self.cursor) {
            self.move_cursor_to(next, extend_selection);
        } else if !extend_selection {
            self.selection_anchor = None;
        }
    }

    pub(super) fn move_prev_word(&mut self, extend_selection: bool) {
        self.move_cursor_to(
            prev_word_boundary(&self.input, self.cursor),
            extend_selection,
        );
    }

    pub(super) fn move_next_word(&mut self, extend_selection: bool) {
        self.move_cursor_to(
            next_word_boundary(&self.input, self.cursor),
            extend_selection,
        );
    }

    pub(super) fn move_home(&mut self, extend_selection: bool) {
        self.move_cursor_to(0, extend_selection);
    }

    pub(super) fn move_end(&mut self, extend_selection: bool) {
        self.move_cursor_to(self.input.len(), extend_selection);
    }

    pub(super) fn select_all(&mut self) {
        self.selection_anchor = Some(0);
        self.cursor = self.input.len();
    }

    pub(super) fn refresh_suggestions(&mut self, core: &ChonsoleCore) {
        self.suggestions = core.suggestions(&self.input);
        if self
            .selected_suggestion
            .is_some_and(|idx| idx >= self.suggestions.len())
        {
            self.selected_suggestion = None;
        }
    }

    pub(super) fn complete_first_suggestion(&mut self, core: &ChonsoleCore) {
        self.refresh_suggestions(core);
        self.complete_suggestion(self.selected_suggestion.unwrap_or(0));
    }

    pub(super) fn select_prev_suggestion(&mut self, core: &ChonsoleCore, steps: usize) -> bool {
        self.refresh_suggestions(core);
        if !self.input.starts_with('/') || self.suggestions.is_empty() {
            return false;
        }
        let len = self.suggestions.len();
        let current = self.selected_suggestion.unwrap_or(0);
        let next = current.saturating_sub(steps.max(1));
        self.apply_suggestion_selection(next.min(len - 1));
        true
    }

    pub(super) fn select_next_suggestion(&mut self, core: &ChonsoleCore, steps: usize) -> bool {
        self.refresh_suggestions(core);
        if !self.input.starts_with('/') || self.suggestions.is_empty() {
            return false;
        }
        let len = self.suggestions.len();
        let current = self.selected_suggestion.unwrap_or(usize::MAX);
        let next = if current == usize::MAX {
            0
        } else {
            (current + steps.max(1)).min(len - 1)
        };
        self.apply_suggestion_selection(next);
        true
    }

    fn apply_suggestion_selection(&mut self, idx: usize) {
        let Some(suggestion) = self.suggestions.get(idx) else {
            return;
        };
        self.input = suggestion.command.clone();
        self.cursor = self.input.len();
        self.selection_anchor = None;
        self.selected_suggestion = Some(idx);
    }

    fn complete_suggestion(&mut self, idx: usize) {
        let Some(suggestion) = self.suggestions.get(idx) else {
            return;
        };
        self.input = format!("{} ", suggestion.command);
        self.cursor = self.input.len();
        self.selection_anchor = None;
        self.selected_suggestion = Some(idx);
    }

    pub(super) fn refresh(
        &mut self,
        interface: &NativeInterfaceRef,
        core: &ChonsoleCore,
    ) -> Result<(), Error> {
        let Some(document) = self.document else {
            return Ok(());
        };
        self.refresh_suggestions(core);
        let rml = interface.rml_ui();
        if let Some(root) = self.root {
            rml.element_set_inner_rml(root, &self.render_body())?;
        } else {
            rml.element_set_inner_rml(document, UI_BODY)?;
        }
        self.root = element_by_id(interface, document, "native-chonsole");
        self.lines = element_by_id(interface, document, "native-chonsole-lines");
        if let Some(lines) = self.lines {
            let _ = rml.element_set_scroll_top(lines, 1_000_000);
        }
        Ok(())
    }

    pub(super) fn process_key_up(
        &mut self,
        interface: &NativeInterfaceRef,
        key_code: i32,
    ) -> Result<bool, Error> {
        if let Some(context) = self.context {
            return interface
                .rml_ui()
                .context_process_key_up(context, key_code, 0);
        }
        Ok(false)
    }

    pub(super) fn process_text_input(
        &mut self,
        interface: &NativeInterfaceRef,
        utf8: &str,
    ) -> Result<bool, Error> {
        if let Some(context) = self.context {
            return interface.rml_ui().context_process_text_input(context, utf8);
        }
        Ok(false)
    }

    pub(super) fn mouse_move(
        &mut self,
        interface: &NativeInterfaceRef,
        x: i32,
        y: i32,
    ) -> Result<bool, Error> {
        if !self.visible {
            return Ok(false);
        }
        let Some(context) = self.context else {
            return Ok(false);
        };
        let inside = self.contains(interface, x, y)?;
        let interacting = interface.rml_ui().context_is_mouse_interacting(context)?;
        if !inside && !interacting {
            if self.mouse_captured {
                let _ = interface.rml_ui().context_process_mouse_leave(context);
            }
            self.mouse_captured = false;
            return Ok(false);
        }
        interface
            .rml_ui()
            .context_process_mouse_move(context, x as f32, y as f32, 0)?;
        self.mouse_captured = inside || interacting;
        Ok(inside || interacting)
    }

    pub(super) fn mouse_press(
        &mut self,
        interface: &NativeInterfaceRef,
        x: i32,
        y: i32,
        button: i32,
    ) -> Result<bool, Error> {
        if !self.visible {
            return Ok(false);
        }
        let Some(context) = self.context else {
            return Ok(false);
        };
        if !self.contains(interface, x, y)? && !self.mouse_captured {
            return Ok(false);
        }
        interface
            .rml_ui()
            .context_process_mouse_move(context, x as f32, y as f32, 0)?;
        self.mouse_captured = true;
        interface
            .rml_ui()
            .context_process_mouse_button_down(context, button - 1, 0)
    }

    pub(super) fn mouse_release(
        &mut self,
        interface: &NativeInterfaceRef,
        x: i32,
        y: i32,
        button: i32,
    ) -> Result<(), Error> {
        if !self.visible {
            return Ok(());
        }
        let Some(context) = self.context else {
            return Ok(());
        };
        interface
            .rml_ui()
            .context_process_mouse_move(context, x as f32, y as f32, 0)?;
        let _ = interface
            .rml_ui()
            .context_process_mouse_button_up(context, button - 1, 0);
        self.mouse_captured = interface
            .rml_ui()
            .context_is_mouse_interacting(context)
            .unwrap_or(false);
        Ok(())
    }

    pub(super) fn mouse_wheel(
        &mut self,
        interface: &NativeInterfaceRef,
        up: bool,
        value: f32,
    ) -> Result<bool, Error> {
        if !self.visible {
            return Ok(false);
        }
        let Some(context) = self.context else {
            return Ok(false);
        };
        let mouse = interface.input().get_mouse_state()?;
        if !self.contains(interface, mouse.x as i32, mouse.y as i32)? {
            return Ok(false);
        }
        let delta = if up { value } else { -value };
        interface
            .rml_ui()
            .context_process_mouse_wheel(context, delta, 0.0, 0)
    }

    fn render_body(&self) -> String {
        let suggestions = self.render_suggestions();
        let suggestions = if suggestions.is_empty() {
            String::new()
        } else {
            format!(r#"<div class="suggestions">{suggestions}</div>"#)
        };
        format!(
            r#"<div id="native-chonsole-lines" class="lines">{}</div>{}<div class="input-row"><span class="prompt">&gt;</span>{}</div>"#,
            self.render_lines(),
            suggestions,
            self.render_input(),
        )
    }

    fn render_lines(&self) -> String {
        self.output
            .iter()
            .map(|line| {
                let class = match line.kind {
                    ChonsoleLineKind::Input => "line input-line",
                    ChonsoleLineKind::Output => "line output-line",
                };
                format!(r#"<div class="{class}">{}</div>"#, escape_rml(&line.text))
            })
            .collect::<Vec<_>>()
            .join("")
    }

    fn render_suggestions(&self) -> String {
        self.suggestions
            .iter()
            .enumerate()
            .map(|(idx, suggestion)| {
                let (command, description) = format_suggestion_parts(suggestion);
                let class = if self.selected_suggestion == Some(idx) {
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

    fn render_input(&self) -> String {
        match self.selection_range() {
            Some((start, end)) if self.cursor == start => {
                format!(
                    r#"<span class="input">{}</span><span class="cursor">&nbsp;</span><span class="input selection">{}</span><span class="input">{}</span>"#,
                    escape_rml(&self.input[..start]),
                    escape_rml(&self.input[start..end]),
                    escape_rml(&self.input[end..]),
                )
            }
            Some((start, end)) => {
                format!(
                    r#"<span class="input">{}</span><span class="input selection">{}</span><span class="cursor">&nbsp;</span><span class="input">{}</span>"#,
                    escape_rml(&self.input[..start]),
                    escape_rml(&self.input[start..end]),
                    escape_rml(&self.input[end..]),
                )
            }
            None => {
                let (before_cursor, after_cursor) = self.input.split_at(self.cursor);
                format!(
                    r#"<span class="input">{}</span><span class="cursor">&nbsp;</span><span class="input">{}</span>"#,
                    escape_rml(before_cursor),
                    escape_rml(after_cursor),
                )
            }
        }
    }

    fn contains(&self, interface: &NativeInterfaceRef, x: i32, y: i32) -> Result<bool, Error> {
        if let Some(root) = self.root {
            return interface
                .rml_ui()
                .element_is_point_within_element(root, x as f32, y as f32);
        }
        Ok(false)
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

    fn selection_range(&self) -> Option<(usize, usize)> {
        let anchor = self.selection_anchor?;
        if anchor == self.cursor {
            return None;
        }
        Some((anchor.min(self.cursor), anchor.max(self.cursor)))
    }

    fn delete_selection(&mut self) -> bool {
        let Some((start, end)) = self.selection_range() else {
            return false;
        };
        self.input.drain(start..end);
        self.cursor = start;
        self.selection_anchor = None;
        self.selected_suggestion = None;
        true
    }
}

fn escape_rml(text: &str) -> String {
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

fn format_suggestion_parts(suggestion: &ChonsoleSuggestion) -> (String, String) {
    let command = truncate_chars(&suggestion.command, SUGGESTION_COMMAND_COLUMN_CHARS);
    let description = truncate_chars(&suggestion.description, MAX_SUGGESTION_DESCRIPTION_CHARS);
    (command, description)
}

fn prev_boundary(text: &str, cursor: usize) -> Option<usize> {
    if cursor == 0 {
        return None;
    }
    text[..cursor].char_indices().last().map(|(idx, _)| idx)
}

fn next_boundary(text: &str, cursor: usize) -> Option<usize> {
    if cursor >= text.len() {
        return None;
    }
    text[cursor..]
        .char_indices()
        .nth(1)
        .map(|(idx, _)| cursor + idx)
        .or(Some(text.len()))
}

fn prev_word_boundary(text: &str, cursor: usize) -> usize {
    let mut pos = cursor;
    while let Some(prev) = prev_boundary(text, pos) {
        if !text[prev..pos].chars().all(char::is_whitespace) {
            break;
        }
        pos = prev;
    }
    while let Some(prev) = prev_boundary(text, pos) {
        if text[prev..pos].chars().all(char::is_whitespace) {
            break;
        }
        pos = prev;
    }
    pos
}

fn next_word_boundary(text: &str, cursor: usize) -> usize {
    let mut pos = cursor;
    while let Some(next) = next_boundary(text, pos) {
        if !text[pos..next].chars().all(char::is_whitespace) {
            break;
        }
        pos = next;
    }
    while let Some(next) = next_boundary(text, pos) {
        if text[pos..next].chars().all(char::is_whitespace) {
            break;
        }
        pos = next;
    }
    pos
}

#[cfg(test)]
mod tests {
    use super::{format_suggestion_parts, truncate_chars, ChonsoleSuggestion, ChonsoleView};

    #[test]
    fn edits_at_cursor_and_deletes_words() {
        let mut view = ChonsoleView::default();
        view.set_input("hello brave world");
        view.move_prev_word(false);
        view.delete_prev_word();
        assert_eq!(view.input(), "hello world");
        view.move_home(false);
        view.push_input("say ");
        assert_eq!(view.input(), "say hello world");
        view.move_end(false);
        view.pop_input();
        assert_eq!(view.input(), "say hello worl");
    }

    #[test]
    fn cursor_moves_over_utf8_boundaries() {
        let mut view = ChonsoleView::default();
        view.set_input("aβc");
        view.move_left(false);
        view.move_left(false);
        view.push_input("-");
        assert_eq!(view.input(), "a-βc");
    }

    #[test]
    fn selection_replaces_and_deletes_text() {
        let mut view = ChonsoleView::default();
        view.set_input("hello world");
        view.move_prev_word(true);
        view.push_input("friend");
        assert_eq!(view.input(), "hello friend");
        view.select_all();
        view.pop_input();
        assert_eq!(view.input(), "");
    }

    #[test]
    fn plain_arrows_collapse_selection_like_a_text_editor() {
        let mut view = ChonsoleView::default();
        view.set_input("hello world");
        view.move_prev_word(true);
        assert_eq!(view.selection_range(), Some((6, 11)));
        view.move_left(false);
        assert_eq!(view.selection_range(), None);
        view.push_input("brave ");
        assert_eq!(view.input(), "hello brave world");

        view.select_all();
        view.move_right(false);
        view.push_input("!");
        assert_eq!(view.input(), "hello brave world!");
    }

    #[test]
    fn ctrl_style_deletions_match_console_editing_expectations() {
        let mut view = ChonsoleView::default();
        view.set_input("alpha beta gamma");
        view.move_prev_word(false);
        view.delete_next_word();
        assert_eq!(view.input(), "alpha beta ");
        view.delete_to_start();
        assert_eq!(view.input(), "");

        view.set_input("alpha beta gamma");
        view.move_prev_word(false);
        view.delete_to_end();
        assert_eq!(view.input(), "alpha beta ");
    }

    #[test]
    fn shifted_movement_collapses_selection_when_anchor_is_reached() {
        let mut view = ChonsoleView::default();
        view.set_input("ab");
        view.move_left(true);
        assert_eq!(view.selection_range(), Some((1, 2)));
        view.move_right(true);
        assert_eq!(view.selection_range(), None);
    }

    #[test]
    fn suggestion_descriptions_are_truncated_before_rendering() {
        assert_eq!(truncate_chars("short", 10), "short");
        assert_eq!(truncate_chars("abcdef", 3), "abc...");
        assert_eq!(truncate_chars("aβc", 2), "aβ...");
    }

    #[test]
    fn suggestion_parts_are_bounded_before_rendering() {
        let (command, description) = format_suggestion_parts(&ChonsoleSuggestion {
            command: "/ridiculously-long-command-name".to_string(),
            text: "/ridiculously-long-command-name".to_string(),
            description: "a description that is intentionally long enough to overflow the console row without truncation".to_string(),
        });
        assert_eq!(command, "/ridiculously-lon...");
        assert!(description.starts_with("a description"));
        assert!(description.ends_with("..."));
    }
}
