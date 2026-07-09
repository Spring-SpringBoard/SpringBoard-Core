use std::any::Any;

use spring_native::prelude::{Error, NativeInterfaceRef};

use crate::sbc::command_system::history::HistoryEvent;
use crate::sbc::command_system::model::{Model, ModelFactory};
use crate::sbc::panels::editor::Editor;
use crate::sbc::panels::env::LightingEditor;
use crate::sbc::panels::field::{new_change_queue, new_interaction_queue};
use crate::sbc::panels::input::{PanelInput, PendingAction};
use crate::sbc::panels::view::PanelView;
use crate::sbc::port_flags::{self, PortImpl};

inventory::submit! {
    ModelFactory { make: |iface| Box::new(PanelManager::new(iface)) }
}

/// Coordinates the panel's view (RmlUi lifecycle), input (drag + handlers),
/// and editor (field logic). Implements `Model` so the command system can
/// notify it of history changes (undo/redo → refresh fields).
pub(crate) struct PanelManager {
    interface: NativeInterfaceRef,
    enabled: bool,
    view: PanelView,
    input: PanelInput,
    editor: Option<Box<dyn Editor>>,
    needs_refresh: bool,
    pending_envelopes: Vec<String>,
    next_cmd_id: u64,
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
        let enabled = port_flags::env_panel_impl(&interface) == PortImpl::Rust;
        log::info!(
            "native env panel {}",
            if enabled { "enabled" } else { "disabled" }
        );
        PanelManager {
            interface,
            enabled,
            view: PanelView::default(),
            input: PanelInput::new(new_change_queue(), new_interaction_queue()),
            editor: Some(Box::new(LightingEditor::new())),
            needs_refresh: true,
            pending_envelopes: Vec::new(),
            next_cmd_id: 1_000_000,
        }
    }

    pub fn update(&mut self) -> Result<(), Error> {
        if !self.enabled {
            return Ok(());
        }
        if self.view.ensure(&self.interface)? {
            self.rebuild_editor()?;
        }
        if !self.view.is_ready() {
            return Ok(());
        }

        // Process interaction events (pointer down/up → drag or click-to-edit)
        let actions = self.input.process_interactions();
        for action in actions {
            match action {
                PendingAction::DragEnd(field) => {
                    if let Some(ed) = self.editor.as_deref_mut() {
                        ed.drag_end_field(&field, &self.interface);
                        self.pending_envelopes
                            .extend(ed.process_drag_end(&field, &mut self.next_cmd_id));
                    }
                }
                PendingAction::ClickEdit(field) => {
                    if let Some(ed) = self.editor.as_deref_mut() {
                        ed.begin_edit_field(&field, &self.interface);
                    }
                }
            }
        }

        // Process value changes (edit input "change" events)
        for name in self.input.drain_changes() {
            if let Some(ed) = self.editor.as_deref_mut() {
                self.pending_envelopes.extend(ed.process_change(
                    &name,
                    &self.interface,
                    &mut self.next_cmd_id,
                ));
            }
        }

        // Refresh from engine if needed (undo/redo or startup)
        if self.needs_refresh {
            if let Some(ed) = self.editor.as_mut() {
                ed.refresh_from_engine(&self.interface);
            }
            self.write_field_values();
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

    // ── Input delegation ──

    pub fn key_press(&mut self, key: i32, _scan: i32, _repeat: bool) -> Result<bool, Error> {
        if !self.enabled {
            return Ok(false);
        }
        self.input.key_press(&self.interface, &self.view, key)
    }

    pub fn key_release(&mut self, key: i32, _scan: i32) -> Result<bool, Error> {
        if !self.enabled {
            return Ok(false);
        }
        self.input.key_release(&self.interface, &self.view, key)
    }

    pub fn text_input(&mut self, utf8: &str) -> Result<bool, Error> {
        if !self.enabled {
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

    // ── Internal ──

    fn rebuild_editor(&mut self) -> Result<(), Error> {
        let Some(content) = self.view.content_handle() else {
            return Ok(());
        };
        let document = self
            .view
            .document_handle()
            .expect("document must exist if content exists");

        if let Some(header) = self.view.header_element(&self.interface) {
            let title = self.editor.as_ref().map(|e| e.title()).unwrap_or("Panel");
            let _ = self.interface.rml_ui().element_set_inner_rml(header, title);
        }

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

    fn write_field_values(&self) {
        if let Some(ed) = &self.editor {
            let _ = ed.write_field_values(&self.interface);
        }
    }
}
