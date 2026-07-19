use spring_native::prelude::NativeInterfaceRef;

use crate::sbc::command_system::model::Models;
use crate::sbc::map_settings::commands::{SetSunLightingCommand, SetSunParametersCommand};
use crate::sbc::panels::field::FieldValue;
use crate::sbc::panels::runtime::{Behavior, Event, Item, Outcome, TableModel};

use super::layout;
use super::model::LightingField::*;
use super::model::{LightingField, SUN_DIR_FIELDS, SUN_LIGHTING_FIELDS};

pub(crate) struct LightingBehavior;

impl Behavior for LightingBehavior {
    type Model = TableModel<LightingField>;

    fn layout(&self, _model: &Self::Model) -> Vec<Item<LightingField>> {
        layout::layout()
    }

    fn refresh(
        &mut self,
        model: &mut Self::Model,
        engine: &NativeInterfaceRef,
        _models: &mut Models,
    ) {
        let gfx = engine.gfx();

        if let Ok((v, ..)) = gfx.get_sun("dir", "") {
            model.set(SunDirX, FieldValue::Number(v[0]));
            model.set(SunDirY, FieldValue::Number(v[1]));
            model.set(SunDirZ, FieldValue::Number(v[2]));
        }

        for (key, mode, ground, unit) in [
            ("diffuse", "unit", GroundDiffuse, UnitDiffuse),
            ("ambient", "unit", GroundAmbient, UnitAmbient),
            ("specular", "unit", GroundSpecular, UnitSpecular),
        ] {
            if let Ok((v, ..)) = gfx.get_sun(key, "") {
                model.set(ground, FieldValue::Color(v));
            }
            if let Ok((v, ..)) = gfx.get_sun(key, mode) {
                model.set(unit, FieldValue::Color(v));
            }
        }

        if let Ok((v, ..)) = gfx.get_sun("shadowDensity", "") {
            model.set(GroundShadowDensity, FieldValue::Number(v[0]));
        }
        if let Ok((v, ..)) = gfx.get_sun("shadowDensity", "unit") {
            model.set(ModelShadowDensity, FieldValue::Number(v[0]));
        }

        if let Ok((mode, _)) = engine.config().get_config_int("Shadows", None) {
            let label = match mode {
                0 => "Off",
                2 => "Terrain",
                _ => "Full",
            };
            model.set(ShadowMode, FieldValue::Text(label.to_string()));
        }
    }

    /// `shadowMode` is not a command: it is an engine console action, as in Lua.
    fn apply(
        &mut self,
        event: Event<LightingField>,
        model: &mut Self::Model,
        engine: &NativeInterfaceRef,
    ) -> Outcome {
        let Event::Changed(id, _phase) = event;

        if id == ShadowMode {
            if let FieldValue::Text(mode) = model.value(id) {
                let arg = match mode.as_str() {
                    "Off" => "0",
                    "Terrain" => "2",
                    _ => "1",
                };
                let _ = engine
                    .messages()
                    .send_commands(&format!("shadows {arg}"), "");
            }
            return Outcome::default();
        }

        if SUN_DIR_FIELDS.contains(&id) {
            let number = |id| match model.value(id) {
                FieldValue::Number(n) => n,
                _ => 0.0,
            };
            if let Some(c) = SetSunParametersCommand::from_opts(serde_json::json!({
                "dirX": number(SunDirX),
                "dirY": number(SunDirY),
                "dirZ": number(SunDirZ),
            })) {
                return Outcome::commands(vec![Box::new(c)]);
            }
            return Outcome::default();
        }

        if SUN_LIGHTING_FIELDS.contains(&id) {
            let base = model.field_name(id);
            let opts = match model.value(id) {
                FieldValue::Color(c) => serde_json::json!({ base: c }),
                FieldValue::Number(n) => serde_json::json!({ base: n }),
                _ => return Outcome::default(),
            };
            if let Some(c) = SetSunLightingCommand::from_opts(opts) {
                return Outcome::commands(vec![Box::new(c)]);
            }
        }

        Outcome::default()
    }
}
