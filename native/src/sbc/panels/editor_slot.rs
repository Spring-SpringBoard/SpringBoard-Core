//! The active editor's lifecycle: opening, markup rebuild, refresh flags, and
//! the editing-state handshake (state requests out, selection clearing back).

use spring_native::prelude::{Error, NativeInterfaceRef};

use crate::sbc::command_system::model::Models;
use crate::sbc::panels::editor::Editor;
use crate::sbc::panels::input::PanelInput;
use crate::sbc::panels::registry::editor_by_name;
use crate::sbc::panels::view::PanelView;
use crate::sbc::project::EditorState;
use crate::sbc::states::StateManager;

const EDITOR_FIELDS_MODEL: &str = "editor_fields";

pub(crate) struct EditorSlot {
    editor: Option<Box<dyn Editor>>,
    name: Option<&'static str>,
    needs_refresh: bool,
    /// The open editor's markup has not been generated yet; it is built after
    /// the first refresh, since a model-backed editor has no fields before it.
    needs_rebuild: bool,
    /// Whether the editor state was Default on the previous panel update.
    /// Action strips must clear only when an active editing state *returns* to
    /// Default (normally Escape), not merely because no definition has been
    /// selected yet.
    state_was_default: bool,
    /// Context that owns the editor display model. A panel context is replaced
    /// wholesale on reload, so a different handle means there is nothing to
    /// remove from the new context.
    field_model_context: Option<u64>,
}

impl Default for EditorSlot {
    fn default() -> Self {
        EditorSlot {
            editor: None,
            name: None,
            needs_refresh: false,
            needs_rebuild: false,
            state_was_default: true,
            field_model_context: None,
        }
    }
}

impl EditorSlot {
    pub(crate) fn editor(&self) -> Option<&dyn Editor> {
        self.editor.as_deref()
    }

    pub(crate) fn editor_mut(&mut self) -> Option<&mut (dyn Editor + 'static)> {
        self.editor.as_deref_mut()
    }

    pub(crate) fn close(&mut self) {
        self.editor = None;
        self.name = None;
    }

    /// Context-owned data models outlive their Rust editor objects, so release
    /// them before replacing an editor within the same panel context.
    pub(crate) fn release_bindings(&mut self, interface: &NativeInterfaceRef) -> Result<(), Error> {
        if let Some(editor) = self.editor.as_mut() {
            editor.release_bindings(interface)?;
        }
        if let Some(context) = self.field_model_context.take() {
            interface
                .rml_ui()
                .remove_data_model(context, EDITOR_FIELDS_MODEL)?;
        }
        Ok(())
    }

    /// Capture panel-local state before replacing its short-lived editor.
    pub(crate) fn save_editor_state(&self, state: &mut EditorState) {
        if let Some(editor) = self.editor.as_deref() {
            editor.save_editor_state(state);
            if let Some(name) = self.name {
                let mut brush = state.brush(name).clone();
                editor.write_brush(&mut brush);
                state.save_brush(name, brush);
            }
        }
    }

    /// Restore panel-local state without routing it through field-change
    /// handlers. Rebuild so grids (notably saved brushes) are redrawn too.
    pub(crate) fn load_editor_state(&mut self, state: &EditorState) {
        if let Some(editor) = self.editor.as_deref_mut() {
            editor.load_editor_state(state);
            if let Some(name) = self.name {
                editor.load_brush_state(state.brush(name));
            }
            self.needs_refresh = true;
            self.needs_rebuild = true;
        }
    }

    pub(crate) fn request_refresh(&mut self) {
        self.needs_refresh = true;
    }

    /// Open an editor. Editor buttons are choice-only, as in Chili.
    pub(crate) fn open(
        &mut self,
        name: &'static str,
        interface: &NativeInterfaceRef,
        view: &mut PanelView,
        state: &mut EditorState,
    ) -> Result<(), Error> {
        if view.active_editor() == Some(name) {
            return Ok(());
        }

        let Some(spec) = editor_by_name(name) else {
            log::warn!("no native editor registered as {name}");
            return Ok(());
        };
        self.save_editor_state(state);
        self.release_bindings(interface)?;
        let mut editor = (spec.make)();
        editor.load_editor_state(state);
        editor.load_brush_state(state.brush(name));
        self.editor = Some(editor);
        self.name = Some(name);
        view.set_active_editor(interface, Some(name))?;
        // The markup is built after the first refresh, not before: an editor
        // whose fields come from a model (Teams) has none until it has read it.
        self.needs_refresh = true;
        self.needs_rebuild = true;
        Ok(())
    }

    /// A view that follows external state (Properties tracking the selection)
    /// asks to refresh here, cheaply, every tick.
    pub(crate) fn poll_watch(&mut self, models: &mut Models) {
        if let Some(ed) = self.editor.as_mut() {
            if ed.wants_refresh(models) {
                self.needs_refresh = true;
                self.needs_rebuild |= ed.wants_rebuild();
            }
        }
    }

    /// Refresh from engine if needed (undo/redo, or the editor just opened),
    /// rebuilding the markup first when asked.
    pub(crate) fn maintain(
        &mut self,
        interface: &NativeInterfaceRef,
        view: &PanelView,
        input: &PanelInput,
        models: &mut Models,
    ) -> Result<(), Error> {
        if !self.needs_refresh {
            return Ok(());
        }
        if let Some(ed) = self.editor.as_mut() {
            ed.refresh_from_engine(interface, models);
        }
        if self.needs_rebuild {
            self.needs_rebuild = false;
            self.rebuild(interface, view, input)?;
        }
        self.write_field_values(interface);
        self.needs_refresh = false;
        Ok(())
    }

    pub(crate) fn write_field_values(&self, interface: &NativeInterfaceRef) {
        if let Some(ed) = &self.editor {
            let _ = ed.write_field_values(interface);
        }
    }

    /// A view asked to enter or leave an editing state.
    pub(crate) fn dispatch_state_request(&mut self, models: &mut Models) {
        let Some(request) = self
            .editor
            .as_deref_mut()
            .and_then(|e| e.take_state_request())
        else {
            return;
        };
        models.with::<StateManager, _>(|states, models| states.set_state(request, models));
    }

    /// Clear the editor's action strip when an active editing state *returns*
    /// to Default (normally Escape).
    pub(crate) fn sync_state_selection(
        &mut self,
        interface: &NativeInterfaceRef,
        view: &PanelView,
        models: &mut Models,
    ) {
        let state_is_default = models.get::<StateManager>().is_default();
        let returned_to_default = state_is_default && !self.state_was_default;
        self.state_was_default = state_is_default;
        if !returned_to_default {
            return;
        }
        let Some(document) = view.document_handle() else {
            return;
        };
        if let Some(editor) = self.editor.as_deref_mut() {
            editor.clear_state_selection(interface, document);
        }
    }

    fn rebuild(
        &mut self,
        interface: &NativeInterfaceRef,
        view: &PanelView,
        input: &PanelInput,
    ) -> Result<(), Error> {
        let Some(content) = view.content_handle() else {
            return Ok(());
        };
        let document = view
            .document_handle()
            .expect("document must exist if content exists");
        let rml = interface.rml_ui();
        let (context, context_exists) = rml.document_get_context(document)?;
        if !context_exists {
            return Ok(());
        }

        if self.field_model_context == Some(context) {
            rml.remove_data_model(context, EDITOR_FIELDS_MODEL)?;
        }
        self.field_model_context = None;

        let model = rml.create_data_model(context, EDITOR_FIELDS_MODEL)?;
        if let Some(editor) = self.editor.as_mut() {
            editor.prepare_data_model(&model)?;
        }
        self.field_model_context = Some(context);

        let body = self
            .editor
            .as_ref()
            .map(|e| e.generate_rml())
            .unwrap_or_default();
        // RmlUi resolves bindings as it parses a new element. The model must
        // therefore be present in the parsed body itself; setting it on the
        // pre-existing content host does not establish that scope.
        rml.element_set_inner_rml(
            content,
            &format!(r#"<div data-model="{EDITOR_FIELDS_MODEL}">{body}</div>"#),
        )?;
        // `data-for` rows materialise during the context update. Do that once
        // at rebuild time so an editor can attach listeners to its typed rows
        // without falling back to generated IDs or markup.
        rml.context_update(context)?;

        if let Some(ed) = self.editor.as_mut() {
            ed.set_tooltip_host(view.tooltip().expect("panel tooltip is bound").clone());
            ed.bind_fields(interface, document, input.changes(), input.interactions())?;
        }
        self.write_field_values(interface);
        Ok(())
    }
}
