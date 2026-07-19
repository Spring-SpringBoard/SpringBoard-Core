//! The active editor's lifecycle: opening, markup rebuild, refresh flags, and
//! the editing-state handshake (state requests out, selection clearing back).

use spring_native::prelude::{Error, NativeInterfaceRef};

use crate::sbc::command_system::model::Models;
use crate::sbc::panels::editor::Editor;
use crate::sbc::panels::input::PanelInput;
use crate::sbc::panels::registry::editor_by_name;
use crate::sbc::panels::view::PanelView;
use crate::sbc::states::StateManager;

pub(crate) struct EditorSlot {
    editor: Option<Box<dyn Editor>>,
    needs_refresh: bool,
    /// The open editor's markup has not been generated yet; it is built after
    /// the first refresh, since a model-backed editor has no fields before it.
    needs_rebuild: bool,
    /// Whether the editor state was Default on the previous panel update.
    /// Action strips must clear only when an active editing state *returns* to
    /// Default (normally Escape), not merely because no definition has been
    /// selected yet.
    state_was_default: bool,
}

impl Default for EditorSlot {
    fn default() -> Self {
        EditorSlot {
            editor: None,
            needs_refresh: false,
            needs_rebuild: false,
            state_was_default: true,
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
    ) -> Result<(), Error> {
        if view.active_editor() == Some(name) {
            return Ok(());
        }

        let Some(spec) = editor_by_name(name) else {
            log::warn!("no native editor registered as {name}");
            return Ok(());
        };
        self.editor = Some((spec.make)());
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

        let body = self
            .editor
            .as_ref()
            .map(|e| e.generate_rml())
            .unwrap_or_default();
        interface.rml_ui().element_set_inner_rml(content, &body)?;

        if let Some(ed) = self.editor.as_mut() {
            ed.bind_fields(interface, document, input.changes(), input.interactions())?;
        }
        self.write_field_values(interface);
        Ok(())
    }
}
