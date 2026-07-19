use spring_native::prelude::NativeInterfaceRef;

use crate::sbc::command_system::command::Command;
use crate::sbc::command_system::model::Models;
use crate::sbc::map_settings::commands::SetAtmosphereCommand;
use crate::sbc::panels::field::FieldValue;
use crate::sbc::panels::runtime::{Behavior, Event, Item, Outcome, Phase, TableModel};

use super::layout;
use super::model::SkyField::*;
use super::model::{SkyField, ATMOSPHERE_FIELDS};

pub(crate) struct SkyBehavior;

fn atmosphere(model: &TableModel<SkyField>, id: SkyField) -> Vec<Box<dyn Command>> {
    let name = model.field_name(id);
    let opts = match model.value(id) {
        FieldValue::Color(c) => serde_json::json!({ name: c }),
        FieldValue::Number(n) => serde_json::json!({ name: n }),
        _ => return vec![],
    };
    match SetAtmosphereCommand::from_opts(opts) {
        Some(c) => vec![Box::new(c) as Box<dyn Command>],
        None => vec![],
    }
}

impl Behavior for SkyBehavior {
    type Model = TableModel<SkyField>;

    fn layout(&self, _model: &Self::Model) -> Vec<Item<SkyField>> {
        layout::layout()
    }

    fn refresh(
        &mut self,
        model: &mut Self::Model,
        engine: &NativeInterfaceRef,
        _models: &mut Models,
    ) {
        let gfx = engine.gfx();
        for id in [SunColor, SkyColor, CloudColor, FogColor] {
            if let Ok((v, ..)) = gfx.get_atmosphere(&model.field_name(id), "") {
                model.set(id, FieldValue::Color(v));
            }
        }
        for id in [FogStart, FogEnd] {
            if let Ok((v, ..)) = gfx.get_atmosphere(&model.field_name(id), "") {
                model.set(id, FieldValue::Number(v[0]));
            }
        }
    }

    fn apply(
        &mut self,
        event: Event<SkyField>,
        model: &mut Self::Model,
        engine: &NativeInterfaceRef,
    ) -> Outcome {
        let Event::Changed(id, phase) = event;
        if id == SkyboxTexture {
            if phase == Phase::Commit {
                if let FieldValue::Text(path) = model.value(id) {
                    if let Err(err) = engine.unsynced_ctrl().set_sky_box_texture(&path) {
                        log::warn!("setting skybox texture {path} failed: {err:?}");
                    }
                }
            }
            return Outcome::default();
        }
        if ATMOSPHERE_FIELDS.contains(&id) {
            return Outcome::commands(atmosphere(model, id));
        }
        Outcome::default()
    }
}
