use std::any::Any;

use spring_native::prelude::{Error, NativeInterfaceRef};

use crate::sbc::actions::{self, Action, ActionResult, FileAcceptFn};
use crate::sbc::command_system::history::HistoryEvent;
use crate::sbc::command_system::model::{Model, ModelFactory, Models};
use crate::sbc::envelope::as_preview;
use crate::sbc::panels::asset_picker::AssetPicker;
use crate::sbc::panels::color_picker::{ColorPicker, PickerEvent};
use crate::sbc::panels::editor::Editor;
use crate::sbc::panels::field::FieldValue;
use crate::sbc::panels::field::{new_change_queue, new_interaction_queue};
use crate::sbc::panels::file_dialog::FileDialog;
use crate::sbc::panels::input::{DragTick, PanelInput, PendingAction};
use crate::sbc::panels::new_project_dialog::NewProjectDialog;
use crate::sbc::panels::registry::editor_by_name;
use crate::sbc::panels::view::{PanelView, ShellEvent};
use crate::sbc::port_flags::{self, UiImpl};
use crate::sbc::states::{BrushSettings, StateManager, StateRequest};

inventory::submit! {
    ModelFactory { make: |iface| Box::new(PanelManager::new(iface)) }
}

/// Coordinates the native panel's view (RmlUi lifecycle + shell chrome), input
/// (drag + handlers), and the active editor. Implements `Model` so the command
/// system can notify it of history changes (undo/redo → refresh fields).
pub(crate) struct PanelManager {
    interface: NativeInterfaceRef,
    enabled: bool,
    view: PanelView,
    input: PanelInput,
    editor: Option<Box<dyn Editor>>,
    needs_refresh: bool,
    /// The open editor's markup has not been generated yet; it is built after
    /// the first refresh, since a model-backed editor has no fields before it.
    needs_rebuild: bool,
    pending_envelopes: Vec<String>,
    next_cmd_id: u64,
    picker: ColorPicker,
    asset_picker: AssetPicker,
    file_dialog: FileDialog,
    new_project: NewProjectDialog,
    /// The callback the open file dialog will run against its accepted result,
    /// set when a toolbar action opens the dialog.
    pending_accept: Option<FileAcceptFn>,
    /// Hotkey-matched actions queued in `key_press`, run in `update` where the
    /// models are borrowable.
    pending_actions: Vec<Action>,
    /// The field currently in text-edit mode. Owning this here is what keeps a
    /// commit to exactly one command: the DOM would otherwise fire "change" on
    /// every keystroke.
    editing: Option<String>,
    /// The last field committed by Enter or a select change; the `blur` it
    /// triggers is swallowed.
    just_committed: Option<String>,
    /// The value a numeric drag started from, so the committed command captures
    /// it as the state undo returns to.
    drag_original: Option<(String, FieldValue)>,
    /// The brush revision the fields last showed; a bump means a state changed
    /// the brush and the fields should follow.
    brush_revision: u64,
}

impl Model for PanelManager {
    fn as_any_mut(&mut self) -> &mut dyn Any {
        self
    }
    fn on_history_events(&mut self, _events: &[HistoryEvent]) {
        if self.enabled {
            self.needs_refresh = true;
        }
    }
}

impl Drop for PanelManager {
    fn drop(&mut self) {
        if self.enabled {
            self.view.dispose(&self.interface);
        }
    }
}

impl PanelManager {
    pub fn new(interface: NativeInterfaceRef) -> Self {
        let enabled = port_flags::ui_impl(&interface) == UiImpl::Rust;
        log::info!("native UI {}", if enabled { "enabled" } else { "disabled" });
        PanelManager {
            interface,
            enabled,
            view: PanelView::default(),
            input: PanelInput::new(new_change_queue(), new_interaction_queue()),
            editor: None,
            needs_refresh: false,
            needs_rebuild: false,
            pending_envelopes: Vec::new(),
            next_cmd_id: 1_000_000,
            picker: ColorPicker::default(),
            asset_picker: AssetPicker::default(),
            file_dialog: FileDialog::default(),
            new_project: NewProjectDialog::default(),
            pending_accept: None,
            pending_actions: Vec::new(),
            editing: None,
            just_committed: None,
            drag_original: None,
            brush_revision: 0,
        }
    }

    pub fn update(&mut self, models: &mut Models) -> Result<(), Error> {
        if !self.enabled {
            return Ok(());
        }
        if self.view.ensure(&self.interface)? {
            // A fresh context: every element handle the editor, the pickers and
            // the input layer cached belongs to a document that no longer
            // exists. Start over rather than touch any of them.
            self.editor = None;
            self.editing = None;
            self.just_committed = None;
            self.drag_original = None;
            self.picker.forget_bindings();
            self.asset_picker.forget_bindings();
            self.file_dialog.forget_bindings();
            self.new_project.forget_bindings();
            self.pending_accept = None;
            self.pending_actions.clear();
            self.input.reset();
            self.view.set_active_editor(&self.interface, None)?;
        }
        if !self.view.is_ready() {
            return Ok(());
        }
        if let Some(doc) = self.view.document_handle() {
            self.picker.bind(&self.interface, doc)?;
            self.asset_picker.bind(&self.interface, doc)?;
            self.file_dialog.bind(&self.interface, doc)?;
            self.new_project.bind(&self.interface, doc)?;
        }

        self.process_shell_events(models)?;
        for action in std::mem::take(&mut self.pending_actions) {
            self.run_action(action, models)?;
        }
        self.process_picker()?;
        self.process_asset_picker()?;
        self.process_file_dialog()?;
        self.process_new_project()?;

        self.input.set_cursor(&self.interface);

        // Pointer interactions (pointer down/up → drag or click-to-edit)
        for action in self.input.process_interactions() {
            match action {
                PendingAction::DragEnd(field) => {
                    if let Some(ed) = self.editor.as_deref_mut() {
                        ed.drag_end_field(&field, &self.interface);
                    }
                    self.commit_drag(&field);
                }
                PendingAction::ClickEdit(field) => {
                    if let Some((root, extensions)) =
                        self.editor.as_deref().and_then(|ed| ed.field_asset(&field))
                    {
                        if let Some(doc) = self.view.document_handle() {
                            let exts: Vec<&str> = extensions.iter().map(String::as_str).collect();
                            self.asset_picker
                                .open(&self.interface, doc, &field, &root, &exts)?;
                        }
                        continue;
                    }
                    if let Some(FieldValue::Color(rgba)) =
                        self.editor.as_deref().map(|ed| ed.field_value(&field))
                    {
                        if let Some(doc) = self.view.document_handle() {
                            self.picker.open(&self.interface, doc, &field, rgba)?;
                        }
                        continue;
                    }
                    if let Some(ed) = self.editor.as_deref_mut() {
                        ed.begin_edit_field(&field, &self.interface);
                    }
                    self.editing = Some(field);
                }
            }
        }

        // Advance an in-progress drag from the polled cursor. Each step previews
        // on the engine, so a dragged number is visible before the mouse is
        // released; the undoable command lands on release.
        match self
            .input
            .tick_drag(&self.interface, self.editor.as_deref_mut())
        {
            DragTick::Started(field) => {
                if let Some(ed) = self.editor.as_deref() {
                    self.drag_original = Some((field.clone(), ed.field_value(&field)));
                }
            }
            DragTick::Moved(field) => self.preview_field(&field),
            DragTick::Released(field) => {
                if let Some(ed) = self.editor.as_deref_mut() {
                    ed.drag_end_field(&field, &self.interface);
                }
                self.commit_drag(&field);
            }
            DragTick::Idle => {}
        }

        // Commit requests: a select's "change", Enter in a text field, or a
        // field losing focus.
        for request in self.input.drain_changes() {
            self.commit_field(&request.field, request.from_blur);
        }

        // A view that follows external state (Properties tracking the selection)
        // asks to refresh here, cheaply, every tick.
        if let Some(ed) = self.editor.as_mut() {
            if ed.wants_refresh(models) {
                self.needs_refresh = true;
                self.needs_rebuild |= ed.wants_rebuild();
            }
        }

        // Refresh from engine if needed (undo/redo, or the editor just opened)
        if self.needs_refresh {
            if let Some(ed) = self.editor.as_mut() {
                ed.refresh_from_engine(&self.interface, models);
            }
            if self.needs_rebuild {
                self.needs_rebuild = false;
                self.rebuild_editor()?;
            }
            self.write_field_values();
            // Writing a value back into the DOM makes RmlUi fire `change` for
            // our own write (a checkbox dispatches one when its attribute moves).
            // Those are not user input, and dispatching them would echo the
            // command back. Lua guards the same way, with an `updating` flag.
            self.input.drain_changes();
            self.needs_refresh = false;
        }

        // Editors that own more than fields (the def grids, the brush action
        // buttons) do their work here, outside the RmlUi event dispatch.
        if let (Some(doc), Some(ed)) = (self.view.document_handle(), self.editor.as_deref_mut()) {
            let envelopes = ed.tick(&self.interface, doc, &mut self.next_cmd_id);
            self.pending_envelopes.extend(envelopes);
        }
        self.sync_brush(models);
        self.dispatch_state_request(models);
        self.sync_state_selection(models);

        self.view.update(&self.interface)
    }

    pub fn draw_screen(&mut self) -> Result<(), Error> {
        if !self.enabled {
            return Ok(());
        }
        // The def grids render their thumbnails here, where the GL context is
        // current (creating and drawing to FBO textures).
        if let Some(ed) = self.editor.as_deref_mut() {
            ed.draw_thumbnails(&self.interface);
        }
        self.view.draw(&self.interface)
    }

    pub fn drain_envelopes(&mut self) -> Vec<String> {
        std::mem::take(&mut self.pending_envelopes)
    }

    // ── Shell ──────────────────────────────────────────────────────

    /// Tab and editor-button clicks are queued by the listeners and handled
    /// here, one tick later: rebuilding the DOM while RmlUi is dispatching the
    /// click frees the element it is dispatching to.
    fn process_shell_events(&mut self, models: &mut Models) -> Result<(), Error> {
        for event in self.view.drain_events() {
            match event {
                ShellEvent::Tab(tab) => {
                    self.reset_state(models);
                    self.view.set_tab(&self.interface, tab)?;
                    self.editor = None;
                }
                ShellEvent::Editor(name) => {
                    self.reset_state(models);
                    self.open_editor(name)?;
                }
                ShellEvent::Action(action) => self.run_action(action, models)?,
            }
        }
        Ok(())
    }

    fn reset_state(&mut self, models: &mut Models) {
        models.with::<StateManager, _>(|states, models| {
            states.set_state(StateRequest::Default, models)
        });
    }

    /// Match a key + current modifiers against the action hotkeys, queueing the
    /// match to run next tick. Returns whether a hotkey was claimed.
    fn match_hotkey(&mut self, key: i32) -> bool {
        const SHIFT: u32 = 1 << 0;
        const CTRL: u32 = 1 << 1;
        let mods = self.interface.input().get_mod_key_state().unwrap_or(0);
        let (ctrl, shift) = (mods & CTRL != 0, mods & SHIFT != 0);

        for action in Action::ALL {
            let Some(hk) = action.hotkey() else { continue };
            if hk.ctrl == ctrl
                && hk.shift == shift
                && crate::sbc::keys::is_key(&self.interface, key, hk.key)
            {
                self.pending_actions.push(action);
                return true;
            }
        }
        false
    }

    /// Run a toolbar action or hotkey. Actions either dispatch commands directly,
    /// or ask to open a dialog whose result the manager feeds back.
    pub(crate) fn run_action(&mut self, action: Action, models: &mut Models) -> Result<(), Error> {
        if !actions::can_execute(action, models) {
            return Ok(());
        }
        match actions::execute(action, &self.interface, models, &mut self.next_cmd_id) {
            ActionResult::None => {}
            ActionResult::Commands(envelopes) => self.pending_envelopes.extend(envelopes),
            ActionResult::OpenFileDialog { config, on_accept } => {
                if let Some(doc) = self.view.document_handle() {
                    self.pending_accept = Some(on_accept);
                    self.file_dialog.open(&self.interface, doc, config)?;
                }
            }
            ActionResult::OpenNewProject => {
                if let Some(doc) = self.view.document_handle() {
                    self.new_project.open(&self.interface, doc)?;
                }
            }
        }
        // Paste needs the cursor's ground position, which the action layer can't
        // reach; run it here where the mouse state is available.
        if action == Action::Paste {
            self.run_paste(models);
        }
        Ok(())
    }

    /// Paste the clipboard at the cursor's ground hit.
    fn run_paste(&mut self, models: &mut Models) {
        let Ok(mouse) = self.interface.input().get_mouse_state() else {
            return;
        };
        let Some(hit) = crate::sbc::states::trace_ground(&self.interface, mouse.x, mouse.y) else {
            return;
        };
        let envelopes =
            actions::execute_paste(&self.interface, models, hit.x, hit.z, &mut self.next_cmd_id);
        self.pending_envelopes.extend(envelopes);
    }

    /// Feed a completed file-dialog result to the action that opened it.
    fn process_file_dialog(&mut self) -> Result<(), Error> {
        let Some(doc) = self.view.document_handle() else {
            return Ok(());
        };
        if let Some(result) = self.file_dialog.tick(&self.interface, doc)? {
            if let Some(on_accept) = self.pending_accept.take() {
                let envelopes = on_accept(&result, &self.interface, &mut self.next_cmd_id);
                self.pending_envelopes.extend(envelopes);
            }
        } else if !self.file_dialog.is_open() {
            // The dialog closed (cancel); drop any pending callback.
            self.pending_accept = None;
        }
        Ok(())
    }

    /// Feed a completed new-project result to the action layer.
    fn process_new_project(&mut self) -> Result<(), Error> {
        let Some(doc) = self.view.document_handle() else {
            return Ok(());
        };
        if let Some(result) = self.new_project.tick(&self.interface, doc)? {
            let envelopes = actions::commit_new_project(
                &result.name,
                &result.map_name,
                result.size_x,
                result.size_y,
                &self.interface,
                &mut self.next_cmd_id,
            );
            self.pending_envelopes.extend(envelopes);
        }
        Ok(())
    }

    fn close_top_modal(&mut self) -> Result<bool, Error> {
        let Some(doc) = self.view.document_handle() else {
            return Ok(false);
        };
        if self.picker.is_open() {
            self.picker.close(&self.interface, doc)?;
            return Ok(true);
        }
        if self.asset_picker.cancel_if_open(&self.interface, doc)? {
            return Ok(true);
        }
        if self.file_dialog.cancel_if_open(&self.interface, doc)? {
            self.pending_accept = None;
            return Ok(true);
        }
        if self.new_project.cancel_if_open(&self.interface, doc)? {
            return Ok(true);
        }
        Ok(false)
    }

    /// Toggle an editor: clicking the open one closes it, as in Chili.
    fn open_editor(&mut self, name: &'static str) -> Result<(), Error> {
        if self.view.active_editor() == Some(name) {
            self.editor = None;
            self.view.set_active_editor(&self.interface, None)?;
            return self.view.clear_content(&self.interface);
        }

        let Some(spec) = editor_by_name(name) else {
            log::warn!("no native editor registered as {name}");
            return Ok(());
        };
        self.editor = Some((spec.make)());
        self.view.set_active_editor(&self.interface, Some(name))?;
        // The markup is built after the first refresh, not before: an editor
        // whose fields come from a model (Teams) has none until it has read it.
        self.needs_refresh = true;
        self.needs_rebuild = true;
        Ok(())
    }

    fn rebuild_editor(&mut self) -> Result<(), Error> {
        let Some(content) = self.view.content_handle() else {
            return Ok(());
        };
        let document = self
            .view
            .document_handle()
            .expect("document must exist if content exists");

        let body = self
            .editor
            .as_ref()
            .map(|e| e.generate_rml())
            .unwrap_or_default();
        self.interface
            .rml_ui()
            .element_set_inner_rml(content, &body)?;

        if let Some(ed) = self.editor.as_mut() {
            ed.bind_fields(
                &self.interface,
                document,
                self.input.changes(),
                self.input.interactions(),
            )?;
        }
        self.write_field_values();
        Ok(())
    }

    /// Commit a field once. Committing on Enter hides the input, which fires a
    /// `blur`; that second request must not dispatch another command.
    fn commit_field(&mut self, name: &str, from_blur: bool) {
        if self.editing.as_deref() == Some(name) {
            self.editing = None;
        }
        if from_blur && self.just_committed.as_deref() == Some(name) {
            self.just_committed = None;
            return;
        }
        self.just_committed = (!from_blur).then(|| name.to_string());

        if let Some(ed) = self.editor.as_deref_mut() {
            self.pending_envelopes.extend(ed.process_change(
                name,
                &self.interface,
                &mut self.next_cmd_id,
            ));
        }
    }

    /// Advance a picker drag and handle OK/Cancel.
    ///
    /// Dragging previews the colour on the engine every frame so the scene
    /// shows what is being picked; previews stay out of the undo history.
    /// Accepting dispatches exactly one undoable command, and cancelling
    /// dispatches none.
    fn process_picker(&mut self) -> Result<(), Error> {
        let Some(doc) = self.view.document_handle() else {
            return Ok(());
        };
        if self.picker.tick(&self.interface, doc) {
            if let Some(field) = self.picker.field().map(str::to_string) {
                let rgba = self.picker.rgba();
                self.apply_field_value(&field, FieldValue::Color(rgba), true);
            }
        }

        for event in self.picker.drain_events() {
            let Some(field) = self.picker.field().map(str::to_string) else {
                continue;
            };
            let original = self.picker.original();

            // The preview left the engine on some dragged colour. Undo has to
            // restore the colour the picker opened with, and the committed
            // command captures whatever it finds -- so put the original back
            // (as a preview, off-history) before committing.
            if self.picker.is_previewing() {
                self.apply_field_value(&field, FieldValue::Color(original), true);
            }
            if let PickerEvent::Accept = event {
                let rgba = self.picker.rgba();
                self.apply_field_value(&field, FieldValue::Color(rgba), false);
            }
            self.picker.close(&self.interface, doc)?;
        }
        Ok(())
    }

    /// Push a colour into the field and dispatch its command, either as an
    /// off-history preview or as a committed, undoable change.
    fn apply_field_value(&mut self, field: &str, value: FieldValue, preview: bool) {
        let Some(ed) = self.editor.as_deref_mut() else {
            return;
        };
        ed.set_field_value(field, value, &self.interface);
        let envelopes = ed.process_drag_end(field, &mut self.next_cmd_id);
        self.pending_envelopes.extend(if preview {
            as_preview(envelopes)
        } else {
            envelopes
        });
    }

    /// Dispatch the field's current value as an off-history preview.
    fn preview_field(&mut self, field: &str) {
        let Some(ed) = self.editor.as_deref_mut() else {
            return;
        };
        let envelopes = ed.process_drag_end(field, &mut self.next_cmd_id);
        self.pending_envelopes.extend(as_preview(envelopes));
    }

    /// End a drag with exactly one undoable command.
    ///
    /// The previews already moved the engine off the value the drag began from,
    /// and the committed command captures whatever it finds as the state undo
    /// restores -- so put the original back (off-history) before committing.
    fn commit_drag(&mut self, field: &str) {
        let original = self
            .drag_original
            .take()
            .filter(|(name, _)| name == field)
            .map(|(_, value)| value);

        let Some(ed) = self.editor.as_deref() else {
            return;
        };
        let current = ed.field_value(field);
        if let Some(original) = original {
            self.apply_field_value(field, original, true);
        }
        self.apply_field_value(field, current, false);
    }

    /// Drive the asset picker; an accepted path is written into the field and
    /// dispatched as one command.
    fn process_asset_picker(&mut self) -> Result<(), Error> {
        let Some(doc) = self.view.document_handle() else {
            return Ok(());
        };
        let field = self.asset_picker.field().map(str::to_string);
        let picked = self.asset_picker.tick(&self.interface, doc)?;
        if let (Some(field), Some(path)) = (field, picked) {
            self.apply_field_value(&field, FieldValue::Text(path), false);
        }
        Ok(())
    }

    fn write_field_values(&self) {
        if let Some(ed) = &self.editor {
            let _ = ed.write_field_values(&self.interface);
        }
    }

    /// Keep the panel's fields and the shared brush in step. A state bumps the
    /// brush's revision when the wheel resizes it or a right-click picks a
    /// height, and then the fields follow; otherwise the fields lead.
    fn sync_brush(&mut self, models: &mut Models) {
        let Some(ed) = self.editor.as_deref_mut() else {
            return;
        };
        let brush = models.get::<BrushSettings>();
        if brush.revision != self.brush_revision {
            self.brush_revision = brush.revision;
            let brush = brush.clone();
            ed.read_brush(&brush, &self.interface);
            return;
        }
        ed.write_brush(brush);
    }

    /// A view asked to enter or leave an editing state.
    fn dispatch_state_request(&mut self, models: &mut Models) {
        let Some(request) = self
            .editor
            .as_deref_mut()
            .and_then(|e| e.take_state_request())
        else {
            return;
        };
        models.with::<StateManager, _>(|states, models| states.set_state(request, models));
    }

    fn sync_state_selection(&mut self, models: &mut Models) {
        let state_is_default = models.get::<StateManager>().is_default();
        if !state_is_default {
            return;
        }
        let Some(document) = self.view.document_handle() else {
            return;
        };
        if let Some(editor) = self.editor.as_deref_mut() {
            editor.clear_state_selection(&self.interface, document);
        }
    }

    // ── Input delegation ──

    pub fn key_press(&mut self, key: i32, _scan: i32, _repeat: bool) -> Result<bool, Error> {
        if !self.enabled {
            return Ok(false);
        }
        const RETURN: i32 = 13;
        const ESCAPE: i32 = 27;
        if key == ESCAPE && self.close_top_modal()? {
            return Ok(true);
        }
        // Keys are only ours while a field is being edited; anything else stays
        // available to the chonsole and the engine — except a toolbar/clipboard
        // hotkey, which we claim here and run next tick (where models borrow).
        let Some(name) = self.editing.clone() else {
            return Ok(self.match_hotkey(key));
        };
        if key == RETURN {
            self.commit_field(&name, false);
            return Ok(true);
        }
        if key == ESCAPE {
            self.editing = None;
            if let Some(ed) = self.editor.as_deref_mut() {
                ed.cancel_edit_field(&name, &self.interface);
            }
            return Ok(true);
        }
        self.input.key_press(&self.interface, &self.view, key)
    }

    pub fn key_release(&mut self, key: i32, _scan: i32) -> Result<bool, Error> {
        if !self.enabled || self.editing.is_none() {
            return Ok(false);
        }
        self.input.key_release(&self.interface, &self.view, key)
    }

    pub fn text_input(&mut self, utf8: &str) -> Result<bool, Error> {
        if !self.enabled || self.editing.is_none() {
            return Ok(false);
        }
        self.input.text_input(&self.interface, &self.view, utf8)
    }

    pub fn mouse_move(
        &mut self,
        x: i32,
        y: i32,
        _dx: i32,
        _dy: i32,
        _button: i32,
    ) -> Result<bool, Error> {
        if !self.enabled {
            return Ok(false);
        }
        self.input.mouse_move(&self.interface, &self.view, x, y)
    }

    pub fn mouse_press(&mut self, x: i32, y: i32, button: i32) -> Result<bool, Error> {
        if !self.enabled {
            return Ok(false);
        }
        let modal_open = self.picker.is_open()
            || self.asset_picker.is_open()
            || self.file_dialog.is_open()
            || self.new_project.is_open()
            || self.editor.as_deref().is_some_and(Editor::has_open_modal);
        if !self.view.contains(&self.interface, x, y) && !modal_open {
            return Ok(false);
        }
        self.input
            .mouse_press(&self.interface, &self.view, x, y, button)
    }

    pub fn mouse_release(&mut self, x: i32, y: i32, button: i32) -> Result<(), Error> {
        if !self.enabled {
            return Ok(());
        }
        self.input
            .mouse_release(&self.interface, &self.view, x, y, button)?;
        if let Some(field) = self.input.force_drag_release() {
            if let Some(ed) = self.editor.as_deref_mut() {
                ed.drag_end_field(&field, &self.interface);
            }
            self.commit_drag(&field);
        }
        Ok(())
    }

    pub fn mouse_wheel(&mut self, up: bool, value: f32) -> Result<bool, Error> {
        if !self.enabled {
            return Ok(false);
        }
        self.input
            .mouse_wheel(&self.interface, &self.view, up, value)
    }
}
