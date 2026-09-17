use spring_native::prelude::NativeInterfaceRef;

use crate::sbc::asset_shader::params::{AssetShaderParams, ASSET_SHADER_TAG};
use crate::sbc::command_system::model::Models;
use crate::sbc::lua_bridge;
use crate::sbc::panels::field::FieldValue;
use crate::sbc::panels::runtime::{Behavior, Event, Item, Outcome, TableModel, Watch};

use super::layout;
use super::model::AssetShaderField::*;
use super::model::{AssetShaderField, DEBUG_VIEWS, PREVIEW_MAPS};

/// Feature whose maps the panel previews. The shader gadget names its textures
/// after the featureDef, so this is also the texture stem.
const ASSET: &str = "gen_arch";

#[derive(Default)]
pub(crate) struct AssetShaderBehavior {
    preview: String,
    rebuild: bool,
}

impl Behavior for AssetShaderBehavior {
    type Model = TableModel<AssetShaderField>;

    fn layout(&self, _model: &Self::Model) -> Vec<Item<AssetShaderField>> {
        layout::layout(&self.preview)
    }

    fn refresh(
        &mut self,
        model: &mut Self::Model,
        _engine: &NativeInterfaceRef,
        _models: &mut Models,
    ) {
        self.preview = preview_path(model);
    }

    fn watch(&mut self, _model: &mut Self::Model, _models: &mut Models) -> Watch {
        if std::mem::take(&mut self.rebuild) {
            return Watch::Rebuild;
        }
        Watch::Unchanged
    }

    fn apply(
        &mut self,
        event: Event<AssetShaderField>,
        model: &mut Self::Model,
        engine: &NativeInterfaceRef,
    ) -> Outcome {
        let Event::Changed(id, _phase) = event;

        if id == PreviewMap {
            self.preview = preview_path(model);
            self.rebuild = true;
            return Outcome::default();
        }

        lua_bridge::rules_message(engine, ASSET_SHADER_TAG, params(model).to_payload());
        Outcome::default()
    }
}

fn params(model: &TableModel<AssetShaderField>) -> AssetShaderParams {
    let number = |id| match model.value(id) {
        FieldValue::Number(n) => n,
        _ => 0.0,
    };
    let boolean = |id| matches!(model.value(id), FieldValue::Bool(true));

    AssetShaderParams {
        asset: ASSET.to_string(),
        enabled: matches!(model.value(Enabled), FieldValue::Bool(true)),
        debug_view: debug_index(model),
        detail_tile_fine: number(DetailTileFine),
        detail_tile_coarse: number(DetailTileCoarse),
        detail_strength: number(DetailStrength),
        roughness_bias: number(RoughnessBias),
        shadow_density: number(ShadowDensity),
        shadow_bias: number(ShadowBias),
        ambient_scale: number(AmbientScale),
        ambient_floor: number(AmbientFloor),
        ambient_sky: number(AmbientSky),
        direct_scale: number(DirectScale),
        roughness_floor: number(RoughnessFloor),
        base_detail: boolean(BaseDetail),
        family_detail: boolean(FamilyDetail),
        dirt: boolean(Dirt),
        colour_detail: boolean(ColourDetail),
        metal: boolean(Metal),
    }
}

fn debug_index(model: &TableModel<AssetShaderField>) -> u32 {
    let FieldValue::Text(selected) = model.value(DebugView) else {
        return 0;
    };
    DEBUG_VIEWS
        .iter()
        .position(|name| *name == selected)
        .unwrap_or(0) as u32
}

fn preview_path(model: &TableModel<AssetShaderField>) -> String {
    let FieldValue::Text(selected) = model.value(PreviewMap) else {
        return String::new();
    };
    PREVIEW_MAPS
        .iter()
        .find(|(name, _)| *name == selected)
        // `.dds`, since the generator ships an offline mip chain and the engine only uses an
        // embedded one from a DDS. The panel kept asking for the old `.png` and RmlUi logged
        // "Could not load texture" once per preview, leaving the pane blank.
        .map(|(_, texture)| format!("unittextures/{}.dds", texture.replace("{}", ASSET)))
        .unwrap_or_default()
}
