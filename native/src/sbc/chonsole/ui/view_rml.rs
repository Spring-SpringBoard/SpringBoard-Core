//! RmlUi document lifetime and pointer/key forwarding for Chonsole.

use std::cell::RefCell;
use std::rc::Rc;

use spring_native::{
    prelude::{Error, NativeInterfaceRef},
    RmlChoiceRow, RmlDataChoiceRows, RmlDataTextRows, RmlDataVariable, RmlTextRow,
};

use crate::sbc::rml::{self, element_by_id};

use crate::sbc::chonsole::framework::{ChonsoleLine, ChonsoleLineKind, TextInput};
const UI_CONTEXT: &str = "sbc_native_chonsole";
const UI_BODY: &str = include_str!("ui.rml");
const MODEL_NAME: &str = "chonsole";
const UI_STYLE: &str = concat!(
    include_str!("../../theme/base.rcss"),
    include_str!("../../theme/scrollbars.rcss"),
    include_str!("../../theme/chonsole.rcss"),
);
// Scroll five suggestion rows per wheel notch. Setting scroll_top directly
// bypasses RmlUi's wheel interpolation, so the result is immediate.
const SUGGESTION_WHEEL_STEP: i32 = 135;

pub(super) type SuggestionClickQueue = Rc<RefCell<Vec<usize>>>;
pub(super) type SuggestionHoverQueue = Rc<RefCell<Vec<Option<usize>>>>;

pub(super) struct ChonsoleRml {
    context: Option<u64>,
    document: Option<u64>,
    root: Option<u64>,
    lines: Option<u64>,
    suggestions: Option<u64>,
    line_rows: Option<RmlDataTextRows<'static>>,
    suggestion_rows: Option<RmlDataChoiceRows<'static>>,
    suggestions_hidden: Option<RmlDataVariable<'static, bool>>,
    detail_command: Option<RmlDataVariable<'static, String>>,
    detail_text: Option<RmlDataVariable<'static, String>>,
    input_before: Option<RmlDataVariable<'static, String>>,
    input_selection: Option<RmlDataVariable<'static, String>>,
    input_after: Option<RmlDataVariable<'static, String>>,
    has_selection: Option<RmlDataVariable<'static, bool>>,
    cursor_before_selection: Option<RmlDataVariable<'static, bool>>,
    cursor_after_selection: Option<RmlDataVariable<'static, bool>>,
    pending_lines_scroll: bool,
    pending_suggestion_scroll_top: Option<i32>,
    mouse_position: Option<(i32, i32)>,
    mouse_captured: bool,
    enabled: bool,
}

impl Default for ChonsoleRml {
    fn default() -> Self {
        Self {
            context: None,
            document: None,
            root: None,
            lines: None,
            suggestions: None,
            line_rows: None,
            suggestion_rows: None,
            suggestions_hidden: None,
            detail_command: None,
            detail_text: None,
            input_before: None,
            input_selection: None,
            input_after: None,
            has_selection: None,
            cursor_before_selection: None,
            cursor_after_selection: None,
            pending_lines_scroll: false,
            pending_suggestion_scroll_top: None,
            mouse_position: None,
            mouse_captured: false,
            enabled: true,
        }
    }
}

impl ChonsoleRml {
    pub(super) fn has_document(&self) -> bool {
        self.document.is_some()
    }

    pub(super) fn context_is_alive(&self, interface: &NativeInterfaceRef) -> bool {
        rml::context_is_alive(interface, UI_CONTEXT, self.context)
    }

    /// Returns true only when a document was created during this call.
    pub(super) fn ensure(&mut self, interface: &NativeInterfaceRef) -> Result<bool, Error> {
        if !self.enabled {
            return Ok(false);
        }
        if self.context.is_some() && self.document.is_some() {
            if self.context_is_alive(interface) {
                return Ok(false);
            }
            self.forget();
        }
        let rml = interface.rml_ui();
        if !rml.is_ready()? {
            return Ok(false);
        }
        let (context, created) = rml.create_context(UI_CONTEXT)?;
        if !created {
            return Ok(false);
        }
        let geometry = interface.display().get_view_geometry()?;
        let _ = rml.context_set_dimensions(context, geometry.viewSizeX, geometry.viewSizeY);
        let data_model = rml.create_data_model(context, MODEL_NAME)?;
        self.line_rows = Some(data_model.bind_text_rows("lines")?);
        self.suggestion_rows = Some(data_model.bind_choice_rows("suggestions")?);
        self.suggestions_hidden = Some(data_model.bind("suggestions_hidden", true)?);
        self.detail_command = Some(data_model.bind("detail_command", String::new())?);
        self.detail_text = Some(data_model.bind("detail_text", String::new())?);
        self.input_before = Some(data_model.bind("input_before", String::new())?);
        self.input_selection = Some(data_model.bind("input_selection", String::new())?);
        self.input_after = Some(data_model.bind("input_after", String::new())?);
        self.has_selection = Some(data_model.bind("has_selection", false)?);
        self.cursor_before_selection = Some(data_model.bind("cursor_before_selection", false)?);
        self.cursor_after_selection = Some(data_model.bind("cursor_after_selection", true)?);
        let (document, created) = rml.context_create_document(context, "body")?;
        if !created {
            return Ok(false);
        }
        rml.document_set_title(document, "Native Chonsole")?;
        rml.document_append_to_style_sheet(document, UI_STYLE)?;
        rml.element_set_inner_rml(document, UI_BODY)?;
        rml.document_show(document, None, None)?;
        self.context = Some(context);
        self.document = Some(document);
        self.root = element_by_id(interface, document, "native-chonsole");
        self.lines = element_by_id(interface, document, "native-chonsole-lines");
        self.suggestions = element_by_id(interface, document, "native-chonsole-suggestions");
        Ok(true)
    }

    pub(super) fn update(&mut self, interface: &NativeInterfaceRef) -> Result<(), Error> {
        let Some(context) = self.context else {
            return Ok(());
        };
        let geometry = interface.display().get_view_geometry()?;
        let rml = interface.rml_ui();
        let _ = rml.context_set_dimensions(context, geometry.viewSizeX, geometry.viewSizeY);
        rml.context_update(context)?;
        if self.pending_lines_scroll {
            if let Some(lines) = self.lines {
                let _ = rml.element_set_scroll_top(lines, 1_000_000);
            }
            self.pending_lines_scroll = false;
        }
        if let (Some(suggestions), Some(scroll_top)) =
            (self.suggestions, self.pending_suggestion_scroll_top.take())
        {
            let _ = rml.element_set_scroll_top(suggestions, scroll_top);
        }
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
        self.forget();
    }

    pub(super) fn set_visible(
        &mut self,
        interface: &NativeInterfaceRef,
        visible: bool,
    ) -> Result<(), Error> {
        // Executing a command (`/luaui reload`) can run `Rml::Shutdown()` and
        // free this document mid-call; hiding a dangling handle is a
        // use-after-free. Revalidate the context and drop stale handles.
        if !self.context_is_alive(interface) {
            self.forget();
            return Ok(());
        }
        let Some(document) = self.document else {
            return Ok(());
        };
        let rml = interface.rml_ui();
        if visible {
            rml.document_show(document, None, None)?;
            if let Some(context) = self.context {
                // Keep the engine/editor cursor stable over console controls.
                let _ = rml.context_enable_mouse_cursor(context, false);
                let _ = rml.context_pull_document_to_front(context, document);
            }
        } else {
            rml.document_hide(document)?;
            self.mouse_captured = false;
            if let Some(context) = self.context {
                let _ = rml.context_process_mouse_leave(context);
            }
        }
        Ok(())
    }

    pub(super) fn refresh(
        &mut self,
        input: &TextInput,
        output: &[ChonsoleLine],
        suggestions: &[RmlChoiceRow],
        details: Option<(&str, &str)>,
        suggestion_scroll_top: Option<i32>,
    ) -> Result<(), Error> {
        if self.context.is_none() {
            return Ok(());
        }
        let lines = output
            .iter()
            .map(|line| RmlTextRow {
                text: line.text.clone(),
                muted: line.kind == ChonsoleLineKind::Input,
                visible: true,
            })
            .collect::<Vec<_>>();
        self.line_rows
            .as_ref()
            .expect("chonsole line rows are bound before its markup")
            .set(&lines)?;
        self.suggestion_rows
            .as_ref()
            .expect("chonsole suggestion rows are bound before its markup")
            .set(suggestions)?;
        self.suggestions_hidden
            .as_ref()
            .expect("chonsole visibility is bound before its markup")
            .set(suggestions.is_empty())?;
        self.set_suggestion_details(details)?;
        self.set_input_segments(input)?;

        self.pending_lines_scroll = true;
        self.pending_suggestion_scroll_top = suggestion_scroll_top;
        Ok(())
    }

    pub(super) fn suggestion_scroll_top(&self, interface: &NativeInterfaceRef) -> Option<i32> {
        self.suggestions
            .and_then(|suggestions| interface.rml_ui().element_get_scroll_top(suggestions).ok())
    }

    /// Attach handlers to the current data-for rows after RmlUi has materialized
    /// them. The model owns their contents; this view owns their native input.
    ///
    /// RmlUi replaces data-for rows as the collection changes, so these
    /// handlers deliberately follow each refresh instead of relying on a
    /// bubbling listener on the static container.
    pub(super) fn bind_suggestion_events(
        &self,
        interface: &NativeInterfaceRef,
        count: usize,
        clicks: SuggestionClickQueue,
        hovers: SuggestionHoverQueue,
    ) -> Result<(), Error> {
        for index in 0..count {
            let Some(suggestion) = self.suggestion_row(interface, index) else {
                break;
            };
            let clicked = clicks.clone();
            interface.rml_ui().element_add_event_listener(
                suggestion,
                "click",
                false,
                move || clicked.borrow_mut().push(index),
            )?;
            let hovers_over = hovers.clone();
            interface.rml_ui().element_add_event_listener(
                suggestion,
                "mouseover",
                false,
                move || hovers_over.borrow_mut().push(Some(index)),
            )?;
            let hovers_out = hovers.clone();
            interface.rml_ui().element_add_event_listener(
                suggestion,
                "mouseout",
                false,
                move || hovers_out.borrow_mut().push(None),
            )?;
        }
        Ok(())
    }

    pub(super) fn set_suggestion_rows(&self, rows: &[RmlChoiceRow]) -> Result<(), Error> {
        self.suggestion_rows
            .as_ref()
            .expect("chonsole suggestion rows are bound before its markup")
            .set(rows)
    }

    pub(super) fn set_suggestion_details(
        &self,
        details: Option<(&str, &str)>,
    ) -> Result<(), Error> {
        let (command, text) = details.unwrap_or_default();
        self.detail_command
            .as_ref()
            .expect("chonsole details are bound before its markup")
            .set(command.to_string())?;
        self.detail_text
            .as_ref()
            .expect("chonsole details are bound before its markup")
            .set(text.to_string())
    }

    pub(super) fn process_key_up(
        &self,
        interface: &NativeInterfaceRef,
        key_code: i32,
    ) -> Result<bool, Error> {
        self.context.map_or(Ok(false), |context| {
            interface
                .rml_ui()
                .context_process_key_up(context, key_code, 0)
        })
    }

    pub(super) fn process_text_input(
        &self,
        interface: &NativeInterfaceRef,
        utf8: &str,
    ) -> Result<bool, Error> {
        self.context.map_or(Ok(false), |context| {
            interface.rml_ui().context_process_text_input(context, utf8)
        })
    }

    pub(super) fn mouse_move(
        &mut self,
        interface: &NativeInterfaceRef,
        visible: bool,
        x: i32,
        y: i32,
    ) -> Result<bool, Error> {
        self.mouse_position = Some((x, y));
        if !visible {
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
        visible: bool,
        x: i32,
        y: i32,
        button: i32,
    ) -> Result<bool, Error> {
        self.mouse_position = Some((x, y));
        if !visible {
            return Ok(false);
        }
        let Some(context) = self.context else {
            return Ok(false);
        };
        if !self.contains(interface, x, y)? && !self.mouse_captured {
            return Ok(false);
        }
        let rml = interface.rml_ui();
        rml.context_process_mouse_move(context, x as f32, y as f32, 0)?;
        self.mouse_captured = true;
        let _ = rml.context_process_mouse_button_down(context, button - 1, 0)?;
        // A press inside Chonsole belongs to it even when RmlUi reports that no
        // listener consumed the event. The engine only keeps delivering drag
        // motion to a callback that claims the press; without this, a scrollbar
        // thumb receives its down event but never the subsequent drag moves.
        Ok(true)
    }

    pub(super) fn mouse_release(
        &mut self,
        interface: &NativeInterfaceRef,
        visible: bool,
        x: i32,
        y: i32,
        button: i32,
    ) -> Result<(), Error> {
        self.mouse_position = Some((x, y));
        if !visible {
            return Ok(());
        }
        let Some(context) = self.context else {
            return Ok(());
        };
        let rml = interface.rml_ui();
        rml.context_process_mouse_move(context, x as f32, y as f32, 0)?;
        let _ = rml.context_process_mouse_button_up(context, button - 1, 0);
        self.mouse_captured = rml.context_is_mouse_interacting(context).unwrap_or(false);
        Ok(())
    }

    pub(super) fn mouse_wheel(
        &mut self,
        interface: &NativeInterfaceRef,
        visible: bool,
        up: bool,
        value: f32,
    ) -> Result<bool, Error> {
        if !visible {
            return Ok(false);
        }
        let Some(suggestions) = self.suggestions else {
            return Ok(false);
        };
        // MouseWheel does not carry a position and may be the first pointer
        // callback after the console opens. The cached position is therefore
        // not sufficient to decide ownership; poll the engine just like the
        // shared panel input layer does.
        let mouse = interface.input().get_mouse_state()?;
        let x = mouse.x as i32;
        let y = mouse.y as i32;
        self.mouse_position = Some((x, y));
        let rml = interface.rml_ui();
        if !rml.element_is_point_within_element(suggestions, x as f32, y as f32)? {
            return Ok(false);
        }
        let scroll_top = rml.element_get_scroll_top(suggestions)?;
        let notches = value.abs().max(1.0).round() as i32;
        let delta = SUGGESTION_WHEEL_STEP.saturating_mul(notches);
        let target = if up {
            scroll_top.saturating_sub(delta)
        } else {
            scroll_top.saturating_add(delta)
        };
        rml.element_set_scroll_top(suggestions, target)?;
        Ok(true)
    }

    fn set_input_segments(&self, input: &TextInput) -> Result<(), Error> {
        let value = input.value();
        let (before, selection, after, has_selection, cursor_before_selection) =
            match input.selection_range() {
                Some((start, end)) => (
                    &value[..start],
                    &value[start..end],
                    &value[end..],
                    true,
                    input.cursor() == start,
                ),
                None => {
                    let (before, after) = value.split_at(input.cursor());
                    (before, "", after, false, false)
                }
            };
        self.input_before
            .as_ref()
            .expect("chonsole input is bound before its markup")
            .set(before.to_string())?;
        self.input_selection
            .as_ref()
            .expect("chonsole input is bound before its markup")
            .set(selection.to_string())?;
        self.input_after
            .as_ref()
            .expect("chonsole input is bound before its markup")
            .set(after.to_string())?;
        self.has_selection
            .as_ref()
            .expect("chonsole input is bound before its markup")
            .set(has_selection)?;
        self.cursor_before_selection
            .as_ref()
            .expect("chonsole input is bound before its markup")
            .set(cursor_before_selection)?;
        self.cursor_after_selection
            .as_ref()
            .expect("chonsole input is bound before its markup")
            .set(!cursor_before_selection)
    }

    fn suggestion_row(&self, interface: &NativeInterfaceRef, target: usize) -> Option<u64> {
        let suggestions = self.suggestions?;
        interface
            .rml_ui()
            .element_get_elements_by_class_name(suggestions, "suggestion")
            .ok()?
            .get(target)
            .copied()
    }

    fn contains(&self, interface: &NativeInterfaceRef, x: i32, y: i32) -> Result<bool, Error> {
        let root_contains = self.root.map_or(Ok(false), |root| {
            interface
                .rml_ui()
                .element_is_point_within_element(root, x as f32, y as f32)
        })?;
        if root_contains {
            return Ok(true);
        }

        let geometry = interface.display().get_view_geometry()?;
        let width = geometry.viewSizeX as f32;
        let height = geometry.viewSizeY as f32;
        let left = width * 0.26;
        let top = height * 0.245;
        Ok(x as f32 >= left
            && x as f32 <= left + width * 0.41
            && y as f32 >= top
            && y as f32 <= top + height * 0.47)
    }

    fn forget(&mut self) {
        self.context = None;
        self.document = None;
        self.root = None;
        self.lines = None;
        self.suggestions = None;
        self.line_rows = None;
        self.suggestion_rows = None;
        self.suggestions_hidden = None;
        self.detail_command = None;
        self.detail_text = None;
        self.input_before = None;
        self.input_selection = None;
        self.input_after = None;
        self.has_selection = None;
        self.cursor_before_selection = None;
        self.cursor_after_selection = None;
        self.pending_lines_scroll = false;
        self.pending_suggestion_scroll_top = None;
        self.mouse_position = None;
        self.mouse_captured = false;
    }
}
