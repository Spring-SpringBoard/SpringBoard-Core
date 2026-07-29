use spring_native::prelude::{Error, NativeInterfaceRef};

use crate::sbc::command_system::model::Models;
use crate::sbc::panels::field::{ChangeQueue, InteractionQueue};
use crate::sbc::panels::runtime::{Behavior, EditorModel, Item, Outcome};
use crate::sbc::project::EditorState;
use crate::sbc::rml::element_by_id;
use crate::sbc::states::{BrushSettings, StateRequest};

use super::layout;
use super::model::{MaterialPickerEvent, TexField, TextureUiModel, DNTS_COUNT};

pub(crate) struct TextureBehavior;

impl Behavior for TextureBehavior {
    type Model = TextureUiModel;

    fn layout(&self, model: &TextureUiModel) -> Vec<Item<TexField>> {
        layout::layout(model)
    }

    fn load_editor_state(&mut self, model: &mut TextureUiModel, state: &EditorState) {
        model.load_editor_state(state);
    }

    fn save_editor_state(&self, model: &TextureUiModel, state: &mut EditorState) {
        model.save_editor_state(state);
    }

    fn refresh(
        &mut self,
        model: &mut TextureUiModel,
        engine: &NativeInterfaceRef,
        _models: &mut Models,
    ) {
        // A map with no splat normals has no DNTS to paint, so Lua greys the
        // button out rather than letting the brush no-op.
        model.dnts_available = (0..DNTS_COUNT)
            .filter(|i| {
                engine
                    .gfx()
                    .texture_info(&format!("$ssmf_splat_normals:{i}"))
                    .is_ok_and(|(width, ..)| width > 0)
            })
            .collect();
    }

    fn mount(
        &mut self,
        model: &mut TextureUiModel,
        interface: &NativeInterfaceRef,
        document: u64,
    ) -> Result<(), Error> {
        if let Some(host) = element_by_id(interface, document, "texture-material-dialog") {
            interface
                .rml_ui()
                .element_set_inner_rml(host, &model.material_dialog_rml())?;
        }
        Ok(())
    }

    fn bind(
        &mut self,
        model: &mut TextureUiModel,
        interface: &NativeInterfaceRef,
        document: u64,
        _changes: &ChangeQueue,
        _interactions: &InteractionQueue,
    ) -> Result<(), Error> {
        model
            .actions
            .set_enabled("DNTS", !model.dnts_available.is_empty());
        model.actions.bind(interface, document)?;
        if let Some(cancel) = element_by_id(interface, document, "texture-material-cancel") {
            let events = model.material_picker_events.clone();
            interface
                .rml_ui()
                .element_add_event_listener(cancel, "click", false, move || {
                    events.borrow_mut().push(MaterialPickerEvent::Cancel);
                })?;
        }
        model.render_grids(interface, document)?;
        model.sync_visibility();
        Ok(())
    }

    fn release_bindings(
        &mut self,
        model: &mut TextureUiModel,
        interface: &NativeInterfaceRef,
    ) -> Result<(), Error> {
        model.saved_brush_grid.release_bindings(interface)?;
        model.material_grid.release_bindings(interface)
    }

    fn tick(
        &mut self,
        model: &mut TextureUiModel,
        interface: &NativeInterfaceRef,
        document: u64,
    ) -> Outcome {
        let mode_before = model.paint_mode().to_string();
        model.actions.tick();
        if model.paint_mode() != "paint" && model.material_picker_open {
            model.material_picker_open = false;
        }
        if model.take_grid_clicks(interface).unwrap_or(false) {
            for entry in model.table.fields() {
                let _ = entry.field.write_to_dom(interface);
            }
            let _ = model.render_grids(interface, document);
            model.sync_visibility();
        }
        if model.paint_mode() != mode_before {
            model.sync_visibility();
        }
        if !model.material_picker_open {
            model.update_selected_saved_brush();
        }
        Outcome::default()
    }

    fn state_request(&mut self, model: &mut TextureUiModel) -> Option<StateRequest> {
        model.actions.take_request()
    }

    fn state_cleared(
        &mut self,
        model: &mut TextureUiModel,
        _interface: &NativeInterfaceRef,
        _document: u64,
    ) {
        model.actions.clear();
    }

    fn modal_open(&self, model: &TextureUiModel) -> bool {
        model.material_picker_open
    }

    fn brush_write(&self, model: &TextureUiModel, brush: &mut BrushSettings) {
        model.write_extra(brush);
    }

    fn brush_read(&mut self, model: &mut TextureUiModel, brush: &BrushSettings) {
        // The generic runtime restores fields tagged with the shared brush.
        // Texture carries additional blend/material fields, so restore those
        // from the same snapshot too.
        model.read_brush(brush);
    }
}
