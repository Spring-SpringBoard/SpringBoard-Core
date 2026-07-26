use crate::sbc::panels::fields::{BooleanField, ChoiceField, NumericField};
use crate::sbc::panels::runtime::{TableEntry, TableModel};

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub(crate) enum AssetShaderField {
    Enabled,
    DebugView,
    PreviewMap,
    DetailTileFine,
    DetailTileCoarse,
    DetailStrength,
    RoughnessBias,
    ShadowDensity,
    ShadowBias,
    AmbientScale,
}

use AssetShaderField::*;

/// Debug outputs, in the order the shader's `debugView` uniform expects them.
pub(crate) const DEBUG_VIEWS: &[&str] = &[
    "Final",
    "Albedo",
    "Normal",
    "Detail normal",
    "Roughness",
    "Occlusion",
    "Shadow",
    "Tangent frame",
    "UV gradient",
    "UV checker",
];

/// Maps the panel can show, and the texture each one lives in. `{}` stands for
/// the asset name; the detail map is deliberately not per-asset -- it is one
/// shared tiling texture, which is the whole point of sampling it triplanar.
pub(crate) const PREVIEW_MAPS: &[(&str, &str)] = &[
    ("Albedo", "{}"),
    ("Normal", "{}_normal"),
    ("Material (R rough, G AO)", "{}_material"),
    ("Detail (tiling)", "gen_detail"),
];

pub(crate) fn asset_shader_model() -> TableModel<AssetShaderField> {
    let number = |id, name: &'static str, title: &'static str, value: f32| {
        TableEntry::new(
            id,
            Box::new(NumericField::new(name, title, value).decimals(2)) as _,
        )
    };

    TableModel::new(vec![
        TableEntry::new(
            Enabled,
            Box::new(BooleanField::new("shaderEnabled", "Custom shader", true)),
        ),
        TableEntry::new(
            DebugView,
            Box::new(ChoiceField::new(
                "debugView",
                "Debug view",
                DEBUG_VIEWS.iter().map(|s| (*s).into()).collect(),
            )),
        ),
        TableEntry::new(
            PreviewMap,
            Box::new(ChoiceField::new(
                "previewMap",
                "Map",
                PREVIEW_MAPS
                    .iter()
                    .map(|(name, _)| (*name).into())
                    .collect(),
            )),
        ),
        number(DetailTileFine, "detailTileFine", "Fine tile", 2.5),
        number(DetailTileCoarse, "detailTileCoarse", "Coarse tile", 9.0),
        // 4.0, not 1.0, and calibrated rather than chosen. Captured the same framing at
        // 0.5 through 8 and measured surface contrast on block interiors: 1.0 leaves the
        // stone reading as smooth putty, 8 is visibly crunchy close up, and 4 lands where a
        // Blender render of the same asset sits. See genassets `grain` and `sweep-field`.
        number(DetailStrength, "detailStrength", "Detail", 4.0),
        number(RoughnessBias, "roughnessBias", "Roughness", 0.0),
        number(ShadowDensity, "shadowDensity", "Shadow", 0.7),
        number(ShadowBias, "shadowBias", "Bias", 1.5),
        number(AmbientScale, "ambientScale", "Ambient", 1.0),
    ])
}
