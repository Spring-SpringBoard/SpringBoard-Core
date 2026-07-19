use crate::sbc::panels::runtime::Item;

use super::model::LightingField;
use super::model::LightingField::*;

pub(crate) fn layout() -> Vec<Item<LightingField>> {
    vec![
        Item::Section("Shadows"),
        Item::Field(ShadowMode),
        Item::Row(&[SunDirX, SunDirY, SunDirZ]),
        Item::Section("Sun ground color"),
        Item::Row(&[GroundDiffuse, GroundAmbient, GroundSpecular]),
        Item::Field(GroundShadowDensity),
        Item::Section("Sun unit color"),
        Item::Row(&[UnitDiffuse, UnitAmbient, UnitSpecular]),
        Item::Field(ModelShadowDensity),
    ]
}
