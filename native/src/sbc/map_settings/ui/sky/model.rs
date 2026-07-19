use crate::sbc::panels::fields::{AssetField, ColorField, NumericField};
use crate::sbc::panels::runtime::{TableEntry, TableModel};

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub(crate) enum SkyField {
    SunColor,
    SkyColor,
    CloudColor,
    FogColor,
    FogStart,
    FogEnd,
    SkyboxTexture,
}

use SkyField::*;

/// Sky and fog. Every atmosphere field goes through one command class; the
/// skybox is a texture path applied by its own engine call, as in Lua.
pub(crate) const ATMOSPHERE_FIELDS: &[SkyField] =
    &[SunColor, SkyColor, CloudColor, FogColor, FogStart, FogEnd];

pub(crate) fn sky_model() -> TableModel<SkyField> {
    TableModel::new(vec![
        TableEntry::new(SunColor, Box::new(ColorField::new("sunColor", "Sun"))),
        TableEntry::new(SkyColor, Box::new(ColorField::new("skyColor", "Sky"))),
        TableEntry::new(CloudColor, Box::new(ColorField::new("cloudColor", "Cloud"))),
        TableEntry::new(FogColor, Box::new(ColorField::new("fogColor", "Color"))),
        TableEntry::new(
            FogStart,
            Box::new(
                NumericField::new("fogStart", "Start", 0.0)
                    .min(0.0)
                    .max(1.0)
                    .decimals(2),
            ),
        ),
        TableEntry::new(
            FogEnd,
            Box::new(
                NumericField::new("fogEnd", "End", 0.0)
                    .min(0.0)
                    .max(1.0)
                    .decimals(2),
            ),
        ),
        TableEntry::new(
            SkyboxTexture,
            Box::new(
                AssetField::new("skyboxTexture", "Skybox", "skyboxes")
                    .extensions(&[".dds", ".png", ".jpg", ".tga"]),
            ),
        ),
    ])
}
