use crate::sbc::panels::fields::{ChoiceField, ColorField, NumericField};
use crate::sbc::panels::runtime::{TableEntry, TableModel};

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub(crate) enum LightingField {
    ShadowMode,
    SunDirX,
    SunDirY,
    SunDirZ,
    GroundDiffuse,
    GroundAmbient,
    GroundSpecular,
    GroundShadowDensity,
    UnitDiffuse,
    UnitAmbient,
    UnitSpecular,
    ModelShadowDensity,
}

use LightingField::*;

/// Fields whose changes go through `SetSunLightingCommand`.
pub(crate) const SUN_LIGHTING_FIELDS: &[LightingField] = &[
    GroundDiffuse,
    GroundAmbient,
    GroundSpecular,
    UnitDiffuse,
    UnitAmbient,
    UnitSpecular,
    GroundShadowDensity,
    ModelShadowDensity,
];

pub(crate) const SUN_DIR_FIELDS: &[LightingField] = &[SunDirX, SunDirY, SunDirZ];

/// Lighting — a port of `scen_edit/view/map/lighting_editor.lua`.
pub(crate) fn lighting_model() -> TableModel<LightingField> {
    let dir = |id, name: &'static str, title: &'static str| {
        TableEntry::new(
            id,
            Box::new(
                NumericField::new(name, title, 0.0)
                    .step(0.002)
                    .decimals(2)
                    .compact(),
            ) as _,
        )
    };
    let density = |id, name: &'static str| {
        TableEntry::new(
            id,
            Box::new(
                NumericField::new(name, "Shadow density", 0.0)
                    .min(0.0)
                    .max(1.0)
                    .decimals(2),
            ) as _,
        )
    };
    let color = |id, name: &'static str, title: &'static str| {
        TableEntry::new(id, Box::new(ColorField::new(name, title)) as _)
    };

    TableModel::new(vec![
        TableEntry::new(
            ShadowMode,
            Box::new(ChoiceField::new(
                "shadowMode",
                "Shadows",
                vec!["Off".into(), "Terrain".into(), "Full".into()],
            )),
        ),
        dir(SunDirX, "sunDirX", "Dir X"),
        dir(SunDirY, "sunDirY", "Dir Y"),
        dir(SunDirZ, "sunDirZ", "Dir Z"),
        color(GroundDiffuse, "groundDiffuseColor", "Diffuse"),
        color(GroundAmbient, "groundAmbientColor", "Ambient"),
        color(GroundSpecular, "groundSpecularColor", "Specular"),
        density(GroundShadowDensity, "groundShadowDensity"),
        color(UnitDiffuse, "unitDiffuseColor", "Diffuse"),
        color(UnitAmbient, "unitAmbientColor", "Ambient"),
        color(UnitSpecular, "unitSpecularColor", "Specular"),
        density(ModelShadowDensity, "modelShadowDensity"),
    ])
}
