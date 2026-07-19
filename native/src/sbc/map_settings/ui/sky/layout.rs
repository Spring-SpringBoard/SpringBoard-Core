use crate::sbc::panels::runtime::Item;

use super::model::SkyField;
use super::model::SkyField::*;

pub(crate) fn layout() -> Vec<Item<SkyField>> {
    vec![
        Item::Row(&[SunColor, SkyColor, CloudColor]),
        Item::Field(SkyboxTexture),
        Item::Section("Fog"),
        Item::Row(&[FogColor, FogStart, FogEnd]),
    ]
}
