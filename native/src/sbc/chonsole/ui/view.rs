use spring_native::prelude::{Error, NativeInterfaceRef};

use crate::sbc::chonsole::commands::ChonsoleCore;
use crate::sbc::chonsole::framework::{
    ChonsoleLine, ChonsoleLineKind, ChonsoleResponse, TextInput,
};

use super::view_render::draw_texture_preview;
use super::view_rml::{ChonsoleRml, SuggestionClickQueue, SuggestionHoverQueue};
use super::view_suggestions::SuggestionView;

const MAX_UI_LINES: usize = 200;
// Keep in sync with `.suggestions` and `.suggestion` in `ui.rcss`. RmlUi does
// not expose an element's client height through the native bridge, so keyboard
// navigation uses the same fixed geometry the stylesheet does.
const SUGGESTION_TOP_PADDING: i32 = 4;
const SUGGESTION_ROW_HEIGHT: i32 = 27;
const SUGGESTION_VIEWPORT_HEIGHT: i32 = 380;

#[derive(Default)]
pub(super) struct ChonsoleView {
    rml: ChonsoleRml,
    visible: bool,
    input: TextInput,
    output: Vec<ChonsoleLine>,
    suggestions: SuggestionView,
    suggestion_clicks: SuggestionClickQueue,
    suggestion_hovers: SuggestionHoverQueue,
    hovered_suggestion: Option<usize>,
    reset_suggestion_scroll: bool,
    suggestion_events_dirty: bool,
}

impl ChonsoleView {
    pub(super) fn ensure(
        &mut self,
        interface: &NativeInterfaceRef,
        core: &ChonsoleCore,
    ) -> Result<(), Error> {
        if self.rml.ensure(interface)? {
            self.output.push(ChonsoleLine {
                kind: ChonsoleLineKind::Output,
                text: "native chonsole ready. F10 toggles, /help lists commands.".to_string(),
            });
            self.set_visible(interface, self.visible)?;
            self.refresh(interface, core)?;
        }
        Ok(())
    }

    pub(super) fn update(&mut self, interface: &NativeInterfaceRef) -> Result<(), Error> {
        self.rml.update(interface)?;
        if self.suggestion_events_dirty {
            self.rml.bind_suggestion_events(
                interface,
                self.suggestions.len(),
                self.suggestion_clicks.clone(),
                self.suggestion_hovers.clone(),
            )?;
            self.suggestion_events_dirty = false;
        }
        Ok(())
    }

    pub(super) fn draw_screen(&mut self, interface: &NativeInterfaceRef) -> Result<(), Error> {
        if self.visible {
            draw_texture_preview(interface, &self.input);
        }
        if self.visible && !self.rml.has_document() {
            let gfx = interface.gfx();
            let _ = gfx.begin_text(false);
            let input = if self.input.value().is_empty() {
                ">"
            } else {
                self.input.value()
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
        self.rml.dispose(interface);
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
        self.rml.set_visible(interface, visible)
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
        self.input.value()
    }

    pub(super) fn take_input(&mut self) -> String {
        self.reset_suggestions();
        self.input.take()
    }

    pub(super) fn set_input(&mut self, input: impl Into<String>) {
        self.reset_suggestions();
        self.input.set(input);
    }

    pub(super) fn clear_input(&mut self) {
        self.reset_suggestions();
        self.input.clear();
    }

    pub(super) fn push_input(&mut self, text: &str) {
        self.reset_suggestions();
        self.input.insert(text);
    }

    pub(super) fn pop_input(&mut self) {
        self.reset_suggestions();
        self.input.backspace();
    }

    pub(super) fn delete_input(&mut self) {
        self.reset_suggestions();
        self.input.delete();
    }

    pub(super) fn delete_prev_word(&mut self) {
        self.reset_suggestions();
        self.input.delete_previous_word();
    }

    pub(super) fn delete_next_word(&mut self) {
        self.reset_suggestions();
        self.input.delete_next_word();
    }

    pub(super) fn delete_to_start(&mut self) {
        self.reset_suggestions();
        self.input.delete_to_start();
    }

    pub(super) fn delete_to_end(&mut self) {
        self.reset_suggestions();
        self.input.delete_to_end();
    }

    pub(super) fn move_left(&mut self, extend_selection: bool) {
        self.input.move_left(extend_selection);
    }

    pub(super) fn move_right(&mut self, extend_selection: bool) {
        self.input.move_right(extend_selection);
    }

    pub(super) fn move_prev_word(&mut self, extend_selection: bool) {
        self.input.move_previous_word(extend_selection);
    }

    pub(super) fn move_next_word(&mut self, extend_selection: bool) {
        self.input.move_next_word(extend_selection);
    }

    pub(super) fn move_home(&mut self, extend_selection: bool) {
        self.input.move_home(extend_selection);
    }

    pub(super) fn move_end(&mut self, extend_selection: bool) {
        self.input.move_end(extend_selection);
    }

    pub(super) fn select_all(&mut self) {
        self.input.select_all();
    }

    pub(super) fn selected_text(&self) -> Option<&str> {
        self.input.selected_text()
    }

    pub(super) fn refresh_suggestions(&mut self, core: &ChonsoleCore) {
        self.suggestions.refresh(core, &self.input);
    }

    pub(super) fn select_prev_suggestion(&mut self, core: &ChonsoleCore, steps: usize) -> bool {
        self.suggestions
            .select_previous(core, &mut self.input, steps)
    }

    pub(super) fn select_next_suggestion(&mut self, core: &ChonsoleCore, steps: usize) -> bool {
        self.suggestions.select_next(core, &mut self.input, steps)
    }

    pub(super) fn process_suggestion_clicks(&mut self, core: &ChonsoleCore) -> bool {
        let index = self.suggestion_clicks.borrow_mut().pop();
        index.is_some_and(|index| self.suggestions.select(core, &mut self.input, index))
    }

    pub(super) fn process_suggestion_hovers(&mut self) {
        let hovered = self.suggestion_hovers.borrow_mut().pop();
        self.suggestion_hovers.borrow_mut().clear();
        let Some(hovered) = hovered else {
            return;
        };
        if hovered == self.hovered_suggestion {
            return;
        }
        self.hovered_suggestion = hovered;
        let _ = self
            .rml
            .set_suggestion_rows(&self.suggestions.rml_rows(hovered));
        let _ = self
            .rml
            .set_suggestion_details(self.suggestions.detail(hovered));
    }

    pub(super) fn refresh(
        &mut self,
        interface: &NativeInterfaceRef,
        core: &ChonsoleCore,
    ) -> Result<(), Error> {
        self.refresh_suggestions(core);
        let suggestion_rows = self.suggestions.rml_rows(None);
        let scroll_top = (!self.reset_suggestion_scroll)
            .then(|| self.rml.suggestion_scroll_top(interface))
            .flatten();
        let scroll_top = self
            .suggestions
            .selected_index()
            .map(|selected| reveal_suggestion_scroll_top(scroll_top.unwrap_or_default(), selected))
            .or(scroll_top);
        self.rml.refresh(
            &self.input,
            &self.output,
            &suggestion_rows,
            self.suggestions.detail(None),
            scroll_top,
        )?;
        self.reset_suggestion_scroll = false;
        self.hovered_suggestion = None;
        self.suggestion_hovers.borrow_mut().clear();
        self.suggestion_events_dirty = true;
        Ok(())
    }

    pub(super) fn process_key_up(
        &mut self,
        interface: &NativeInterfaceRef,
        key_code: i32,
    ) -> Result<bool, Error> {
        self.rml.process_key_up(interface, key_code)
    }

    pub(super) fn process_text_input(
        &mut self,
        interface: &NativeInterfaceRef,
        utf8: &str,
    ) -> Result<bool, Error> {
        self.rml.process_text_input(interface, utf8)
    }

    pub(super) fn mouse_move(
        &mut self,
        interface: &NativeInterfaceRef,
        x: i32,
        y: i32,
    ) -> Result<bool, Error> {
        self.rml.mouse_move(interface, self.visible, x, y)
    }

    pub(super) fn mouse_press(
        &mut self,
        interface: &NativeInterfaceRef,
        x: i32,
        y: i32,
        button: i32,
    ) -> Result<bool, Error> {
        self.rml.mouse_press(interface, self.visible, x, y, button)
    }

    pub(super) fn mouse_release(
        &mut self,
        interface: &NativeInterfaceRef,
        x: i32,
        y: i32,
        button: i32,
    ) -> Result<(), Error> {
        self.rml
            .mouse_release(interface, self.visible, x, y, button)
    }

    pub(super) fn mouse_wheel(
        &mut self,
        interface: &NativeInterfaceRef,
        up: bool,
        value: f32,
    ) -> Result<bool, Error> {
        self.rml.mouse_wheel(interface, self.visible, up, value)
    }

    fn reset_suggestions(&mut self) {
        self.suggestions.reset();
        self.reset_suggestion_scroll = true;
    }
}

/// Return the least scroll offset that makes `selected` fully visible.
///
/// The selected row may have changed while the list's old DOM still holds the
/// previous offset. `refresh` carries this target over to the replacement DOM,
/// so repeated Tab, Up/Down, and Page Up/Down navigation never leaves the
/// active completion outside the viewport.
fn reveal_suggestion_scroll_top(current: i32, selected: usize) -> i32 {
    let row_top = SUGGESTION_TOP_PADDING.saturating_add(
        i32::try_from(selected)
            .unwrap_or(i32::MAX)
            .saturating_mul(SUGGESTION_ROW_HEIGHT),
    );
    let row_bottom = row_top.saturating_add(SUGGESTION_ROW_HEIGHT);
    if row_top < current {
        row_top
    } else if row_bottom > current.saturating_add(SUGGESTION_VIEWPORT_HEIGHT) {
        row_bottom.saturating_sub(SUGGESTION_VIEWPORT_HEIGHT)
    } else {
        current
    }
}

#[cfg(test)]
mod tests {
    use super::reveal_suggestion_scroll_top;

    #[test]
    fn selection_scrolls_down_only_after_leaving_the_viewport() {
        assert_eq!(reveal_suggestion_scroll_top(0, 12), 0);
        assert_eq!(reveal_suggestion_scroll_top(0, 13), 2);
        assert_eq!(reveal_suggestion_scroll_top(0, 14), 29);
    }

    #[test]
    fn selection_scrolls_up_only_far_enough_to_reveal_the_row() {
        assert_eq!(reveal_suggestion_scroll_top(191, 7), 191);
        assert_eq!(reveal_suggestion_scroll_top(191, 6), 166);
    }
}
