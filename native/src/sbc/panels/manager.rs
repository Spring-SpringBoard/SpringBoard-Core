use std::any::Any;

use spring_native::prelude::{Error, NativeInterfaceRef};

use crate::sbc::command_system::history::HistoryEvent;
use crate::sbc::command_system::model::{Model, ModelFactory, Models};
use crate::sbc::panels::asset_picker::AssetPicker;
use crate::sbc::panels::color_picker::{ColorPicker, PickerEvent};
use crate::sbc::panels::editor::Editor;
use crate::sbc::panels::editor_base::as_preview;
use crate::sbc::panels::field::{new_change_queue, new_interaction_queue};
use crate::sbc::panels::input::{PanelInput, PendingAction};
use crate::sbc::panels::registry::editor_by_name;
use crate::sbc::panels::view::{PanelView, ShellEvent};
use crate::sbc::port_flags::{self, UiImpl};

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
    pending_envelopes: Vec<String>,
    next_cmd_id: u64,
    picker: ColorPicker,
    asset_picker: AssetPicker,
    /// The field currently in text-edit mode. Owning this here is what keeps a
    /// commit to exactly one command: the DOM would otherwise fire "change" on
    /// every keystroke.
    editing: Option<String>,
    /// The last field committed by Enter or a select change; the `blur` it
    /// triggers is swallowed.
    just_committed: Option<String>,
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
            pending_envelopes: Vec::new(),
            next_cmd_id: 1_000_000,
            picker: ColorPicker::default(),
            asset_picker: AssetPicker::default(),
            editing: None,
            just_committed: None,
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
            self.picker.forget_bindings();
            self.asset_picker.forget_bindings();
            self.input.reset();
            self.view.set_active_editor(&self.interface, None)?;
        }
        if !self.view.is_ready() {
            return Ok(());
        }
        if let Some(doc) = self.view.document_handle() {
            self.picker.bind(&self.interface, doc)?;
            self.asset_picker.bind(&self.interface, doc)?;
        }

        self.process_shell_events()?;
        self.process_picker()?;
        self.process_asset_picker()?;

        self.input.set_cursor(&self.interface);

        // Pointer interactions (pointer down/up → drag or click-to-edit)
        for action in self.input.process_interactions() {
            match action {
                PendingAction::DragEnd(field) => {
                    if let Some(ed) = self.editor.as_deref_mut() {
                        ed.drag_end_field(&field, &self.interface);
                        self.pending_envelopes
                            .extend(ed.process_drag_end(&field, &mut self.next_cmd_id));
                    }
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
                    if let Some(rgba) = self.editor.as_deref().and_then(|ed| ed.field_color(&field))
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

        // Advance an in-progress drag from the polled cursor.
        self.input
            .tick_drag(&self.interface, self.editor.as_deref_mut());

        // Commit requests: a select's "change", Enter in a text field, or a
        // field losing focus.
        for request in self.input.drain_changes() {
            self.commit_field(&request.field, request.from_blur);
        }

        // Refresh from engine if needed (undo/redo, or the editor just opened)
        if self.needs_refresh {
            if let Some(ed) = self.editor.as_mut() {
                ed.refresh_from_engine(&self.interface, models);
            }
            self.write_field_values();
            // Writing a value back into the DOM makes RmlUi fire `change` for
            // our own write (a checkbox dispatches one when its attribute moves).
            // Those are not user input, and dispatching them would echo the
            // command back. Lua guards the same way, with an `updating` flag.
            self.input.drain_changes();
            self.needs_refresh = false;
        }

        self.view.update(&self.interface)
    }

    pub fn draw_screen(&mut self) -> Result<(), Error> {
        if !self.enabled {
            return Ok(());
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
    fn process_shell_events(&mut self) -> Result<(), Error> {
        for event in self.view.drain_events() {
            match event {
                ShellEvent::TabClicked(tab) => {
                    self.view.set_tab(&self.interface, tab)?;
                    self.editor = None;
                }
                ShellEvent::EditorClicked(name) => self.open_editor(name)?,
            }
        }
        Ok(())
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
        self.rebuild_editor()?;
        self.needs_refresh = true;
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
                self.apply_picker_color(&field, rgba, true);
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
                self.apply_picker_color(&field, original, true);
            }
            if let PickerEvent::Accept = event {
                let rgba = self.picker.rgba();
                self.apply_picker_color(&field, rgba, false);
            }
            self.picker.close(&self.interface, doc)?;
        }
        Ok(())
    }

    /// Push a colour into the field and dispatch its command, either as an
    /// off-history preview or as a committed, undoable change.
    fn apply_picker_color(&mut self, field: &str, rgba: [f32; 4], preview: bool) {
        let Some(ed) = self.editor.as_deref_mut() else {
            return;
        };
        ed.set_field_color(field, rgba, &self.interface);
        let envelopes = ed.process_drag_end(field, &mut self.next_cmd_id);
        self.pending_envelopes.extend(if preview {
            as_preview(envelopes)
        } else {
            envelopes
        });
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
            if let Some(ed) = self.editor.as_deref_mut() {
                ed.set_field_text(&field, &path, &self.interface);
                self.pending_envelopes
                    .extend(ed.process_drag_end(&field, &mut self.next_cmd_id));
            }
        }
        Ok(())
    }

    fn write_field_values(&self) {
        if let Some(ed) = &self.editor {
            let _ = ed.write_field_values(&self.interface);
        }
    }

    // ── Input delegation ──

    pub fn key_press(&mut self, key: i32, _scan: i32, _repeat: bool) -> Result<bool, Error> {
        if !self.enabled {
            return Ok(false);
        }
        const RETURN: i32 = 13;
        const ESCAPE: i32 = 27;
        // Keys are only ours while a field is being edited; anything else stays
        // available to the chonsole and the engine.
        let Some(name) = self.editing.clone() else {
            return Ok(false);
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
        self.input.mouse_move(
            &self.interface,
            &self.view,
            self.editor.as_deref_mut(),
            x,
            y,
        )
    }

    pub fn mouse_press(&mut self, x: i32, y: i32, button: i32) -> Result<bool, Error> {
        if !self.enabled {
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
            .mouse_release(&self.interface, &self.view, x, y, button)
    }

    pub fn mouse_wheel(&mut self, up: bool, value: f32) -> Result<bool, Error> {
        if !self.enabled {
            return Ok(false);
        }
        self.input
            .mouse_wheel(&self.interface, &self.view, up, value)
    }
}
