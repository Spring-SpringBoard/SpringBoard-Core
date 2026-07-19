use spring_native::prelude::NativeInterfaceRef;

use crate::sbc::command_system::command::Command;
use crate::sbc::command_system::model::Models;
use crate::sbc::map_settings::commands::SetWaterParamsCommand;
use crate::sbc::panels::field::FieldValue;
use crate::sbc::panels::runtime::{Behavior, Event, Item, Outcome, TableModel};

use super::layout;
use super::model::WaterField;
use super::model::WaterField::*;

pub(crate) struct WaterBehavior;

fn water(model: &TableModel<WaterField>, id: WaterField) -> Vec<Box<dyn Command>> {
    let name = model.field_name(id);
    let opts = match model.value(id) {
        // The engine's water colours are RGB; the picker carries an alpha.
        FieldValue::Color(c) => serde_json::json!({ name: [c[0], c[1], c[2]] }),
        FieldValue::Number(n) => serde_json::json!({ name: n }),
        FieldValue::Bool(b) => serde_json::json!({ name: b }),
        FieldValue::Text(t) => serde_json::json!({ name: t }),
    };
    match SetWaterParamsCommand::from_opts(opts) {
        Some(c) => vec![Box::new(c) as Box<dyn Command>],
        None => vec![],
    }
}

impl Behavior for WaterBehavior {
    type Model = TableModel<WaterField>;

    fn layout(&self, _model: &Self::Model) -> Vec<Item<WaterField>> {
        layout::layout()
    }

    fn refresh(
        &mut self,
        model: &mut Self::Model,
        engine: &NativeInterfaceRef,
        _models: &mut Models,
    ) {
        let gfx = engine.gfx();

        for id in [
            NumTiles,
            PerlinStartFreq,
            PerlinLacunarity,
            PerlinAmplitude,
            DiffuseFactor,
            SpecularFactor,
            SpecularPower,
            AmbientFactor,
            FresnelMin,
            FresnelMax,
            FresnelPower,
            ReflectionDistortion,
            BlurBase,
            BlurExponent,
            RepeatX,
            RepeatY,
        ] {
            if let Ok((v, ..)) = gfx.get_water_rendering(&model.field_name(id), "") {
                model.set(id, FieldValue::Number(v[0]));
            }
        }

        for id in [DiffuseColor, SpecularColor, PlaneColor] {
            if let Ok((v, ..)) = gfx.get_water_rendering(&model.field_name(id), "") {
                model.set(id, FieldValue::Color(v));
            }
        }

        // Boolean water params come back in the result's `boolValue`, flagged by
        // `hasBool` -- not in the float array, which stays zero for them.
        for id in [ForceRendering, HasWaterPlane, ShoreWaves] {
            if let Ok((_, _, bool_value, has_bool, _)) =
                gfx.get_water_rendering(&model.field_name(id), "")
            {
                if has_bool {
                    model.set(id, FieldValue::Bool(bool_value));
                }
            }
        }
    }

    fn apply(
        &mut self,
        event: Event<WaterField>,
        model: &mut Self::Model,
        _engine: &NativeInterfaceRef,
    ) -> Outcome {
        let Event::Changed(id, _phase) = event;
        Outcome::commands(water(model, id))
    }
}
