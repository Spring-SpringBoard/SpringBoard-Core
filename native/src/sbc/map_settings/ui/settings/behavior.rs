use spring_native::prelude::{Error, NativeInterfaceRef};

use crate::sbc::command_system::command::Command;
use crate::sbc::command_system::model::Models;
use crate::sbc::map_settings::commands::{
    SetMapRenderingParamsCommand, SetMapShadingTextureEnabledCommand,
};
use crate::sbc::panels::field::{ChangeQueue, FieldValue, InteractionQueue};
use crate::sbc::panels::runtime::{Behavior, Event, Item, Outcome};
use crate::sbc::rml::element_by_id;
use crate::sbc::textures::commands::{CreateShadingTextureCommand, ImportShadingImageCommand};
use crate::sbc::textures::TextureModel;

use super::layout;
use super::model::SettingsField::*;
use super::model::{
    SettingsField, SettingsModel, ShadingEvent, ShadingSource, BOOLEANS, SHADING_TOGGLES,
    SPLAT_MULTS, SPLAT_SCALES,
};

impl SettingsModel {
    fn rendering(&self, id: SettingsField) -> Vec<Box<dyn Command>> {
        let opts = if SPLAT_SCALES.contains(&id) {
            serde_json::json!({ "splatTexScales": self.splat_values(SPLAT_SCALES) })
        } else if SPLAT_MULTS.contains(&id) {
            serde_json::json!({ "splatTexMults": self.splat_values(SPLAT_MULTS) })
        } else {
            let name = self.table.field_name(id);
            match self.table.value(id) {
                FieldValue::Bool(b) => serde_json::json!({ name: b }),
                FieldValue::Text(t) => serde_json::json!({ name: t }),
                FieldValue::Number(n) => serde_json::json!({ name: n }),
                FieldValue::Color(c) => serde_json::json!({ name: c }),
            }
        };
        match SetMapRenderingParamsCommand::from_opts(opts) {
            Some(c) => vec![Box::new(c)],
            None => vec![],
        }
    }
}

pub(crate) struct SettingsBehavior;

impl Behavior for SettingsBehavior {
    type Model = SettingsModel;

    fn layout(&self, model: &SettingsModel) -> Vec<Item<SettingsField>> {
        layout::layout(model)
    }

    fn refresh(
        &mut self,
        model: &mut SettingsModel,
        engine: &NativeInterfaceRef,
        models: &mut Models,
    ) {
        let gfx = engine.gfx();
        for id in BOOLEANS {
            let name = model.table.field_name(*id);
            if let Ok((_, _, bool_value, has_bool, _)) = gfx.get_map_rendering(&name, "") {
                if has_bool {
                    model.table.set(*id, FieldValue::Bool(bool_value));
                }
            }
        }
        if let Ok((values, ..)) = gfx.get_map_rendering("splatTexScales", "") {
            for (id, value) in SPLAT_SCALES.iter().zip(values) {
                model.table.set(*id, FieldValue::Number(value));
            }
        }
        if let Ok((values, ..)) = gfx.get_map_rendering("splatTexMults", "") {
            for (id, value) in SPLAT_MULTS.iter().zip(values) {
                model.table.set(*id, FieldValue::Number(value));
            }
        }
        let textures = &models.get::<TextureModel>().shading;
        for (field, shading, _) in SHADING_TOGGLES {
            model
                .shading_enabled
                .insert((*field).to_string(), textures.texture(shading).is_some());
        }
    }

    fn apply(
        &mut self,
        event: Event<SettingsField>,
        model: &mut SettingsModel,
        _engine: &NativeInterfaceRef,
    ) -> Outcome {
        let Event::Changed(id, _phase) = event;
        // The detail texture is a shading channel, not a rendering param: Lua
        // routes it through `AssignShadingTexture("detail", ...)`, and the
        // native equivalent is the shading-image import.
        if id == DetailTexture {
            let FieldValue::Text(path) = model.table.value(DetailTexture) else {
                return Outcome::default();
            };
            if path.is_empty() {
                return Outcome::default();
            }
            model.shading_enabled.insert("tex_detail".to_string(), true);
            let Some(command) = ImportShadingImageCommand::from_fields(serde_json::json!({
                "texType": "detail",
                // Asset paths are pack-relative; the VFS sees them under the
                // asset root.
                "texturePath": format!("springboard/assets/{path}"),
            })) else {
                return Outcome::default();
            };
            return Outcome::commands(vec![Box::new(command)]);
        }
        if matches!(id, ShadingWidth | ShadingHeight) {
            return Outcome::default();
        }
        Outcome::commands(model.rendering(id))
    }

    fn mount(
        &mut self,
        model: &mut SettingsModel,
        interface: &NativeInterfaceRef,
        document: u64,
    ) -> Result<(), Error> {
        if let Some(host) = element_by_id(interface, document, "map-shading-modal") {
            interface
                .rml_ui()
                .element_set_inner_rml(host, &model.dialog_markup())?;
        }
        Ok(())
    }

    fn bind(
        &mut self,
        model: &mut SettingsModel,
        interface: &NativeInterfaceRef,
        document: u64,
        _changes: &ChangeQueue,
        _interactions: &InteractionQueue,
    ) -> Result<(), Error> {
        for (field, shading, _) in SHADING_TOGGLES {
            let Some(button) = element_by_id(interface, document, &format!("shading-{field}"))
            else {
                continue;
            };
            let events = model.shading_events.clone();
            let name = (*shading).to_string();
            interface
                .rml_ui()
                .element_add_event_listener(button, "click", false, move || {
                    events.borrow_mut().push(ShadingEvent::Open(name.clone()));
                })?;
        }
        for (id, event) in [
            ("shading-new", ShadingEvent::ShowNew),
            ("shading-existing", ShadingEvent::Existing),
            ("shading-create", ShadingEvent::New),
            ("shading-disable", ShadingEvent::Disable),
            ("shading-cancel", ShadingEvent::Cancel),
        ] {
            let Some(button) = element_by_id(interface, document, id) else {
                continue;
            };
            let events = model.shading_events.clone();
            interface
                .rml_ui()
                .element_add_event_listener(button, "click", false, move || {
                    events.borrow_mut().push(event.clone());
                })?;
        }
        model.render_existing_grid(interface, document)?;
        model.render_shading_fields(interface, document);
        model.render_dialog(interface, document);
        Ok(())
    }

    fn tick(
        &mut self,
        model: &mut SettingsModel,
        interface: &NativeInterfaceRef,
        document: u64,
    ) -> Outcome {
        let mut commands: Vec<Box<dyn Command>> = Vec::new();
        let events: Vec<ShadingEvent> = model.shading_events.borrow_mut().drain(..).collect();
        for event in events {
            match event {
                ShadingEvent::Open(name) => {
                    model.dialog = Some(name);
                    model.shading_source = None;
                }
                ShadingEvent::ShowNew => model.shading_source = Some(ShadingSource::New),
                ShadingEvent::Existing => model.shading_source = Some(ShadingSource::Existing),
                ShadingEvent::Cancel => {
                    model.dialog = None;
                    model.shading_source = None;
                }
                ShadingEvent::New | ShadingEvent::Disable => {
                    if let Some(name) = model.dialog.take() {
                        let enabled = matches!(event, ShadingEvent::New);
                        let Some((field, _, _)) = SHADING_TOGGLES
                            .iter()
                            .find(|(_, shading, _)| *shading == name)
                        else {
                            continue;
                        };
                        model.shading_enabled.insert((*field).to_string(), enabled);
                        if enabled {
                            let width = dialog_dimension(model, ShadingWidth);
                            let height = dialog_dimension(model, ShadingHeight);
                            commands.push(Box::new(CreateShadingTextureCommand::new(
                                name.clone(),
                                width,
                                height,
                                default_shading_color(&name),
                            )));
                        } else {
                            commands.push(Box::new(SetMapShadingTextureEnabledCommand::new(
                                name, false,
                            )));
                        }
                        model.shading_source = None;
                    }
                }
            }
        }
        if model.dialog.is_some() && model.shading_source == Some(ShadingSource::Existing) {
            for id in model.shading_grid.drain_clicks() {
                if model
                    .shading_grid
                    .item(&id)
                    .is_some_and(|item| !item.is_directory)
                {
                    if let Some(name) = model.dialog.take() {
                        let Some((field, _, _)) = SHADING_TOGGLES
                            .iter()
                            .find(|(_, shading, _)| *shading == name)
                        else {
                            continue;
                        };
                        model.shading_enabled.insert((*field).to_string(), true);
                        model.shading_source = None;
                        if let Some(c) = ImportShadingImageCommand::from_fields(serde_json::json!({
                            "texType": name,
                            "texturePath": id,
                        })) {
                            commands.push(Box::new(c));
                        }
                    }
                }
            }
        } else {
            model.shading_grid.drain_clicks();
        }
        model.render_shading_fields(interface, document);
        model.render_dialog(interface, document);
        Outcome::commands(commands)
    }

    fn modal_open(&self, model: &SettingsModel) -> bool {
        model.dialog.is_some()
    }
}

fn dialog_dimension(model: &SettingsModel, id: SettingsField) -> i32 {
    match model.table.value(id) {
        FieldValue::Number(value) if value.is_finite() && value > 0.0 => value.round() as i32,
        _ => 1024,
    }
}

fn default_shading_color(name: &str) -> [f32; 4] {
    match name {
        "splat_distr" => [1.0, 0.0, 0.0, 0.0],
        name if name.starts_with("splat_normals") => [0.5, 0.5, 1.0, 0.5],
        "emission" | "refl" => [0.0, 0.0, 0.0, 0.2],
        _ => [0.0, 0.0, 0.0, 1.0],
    }
}
