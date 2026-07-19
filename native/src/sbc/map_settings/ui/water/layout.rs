use crate::sbc::panels::runtime::Item;

use super::model::WaterField;
use super::model::WaterField::*;

pub(crate) fn layout() -> Vec<Item<WaterField>> {
    vec![
        Item::Row(&[ForceRendering, NumTiles]),
        Item::Field(NormalTexture),
        Item::Section("Water - perlin noise"),
        Item::Row(&[PerlinStartFreq, PerlinLacunarity]),
        Item::Row(&[PerlinAmplitude]),
        Item::Section("Water - diffuse"),
        Item::Row(&[DiffuseFactor, DiffuseColor]),
        Item::Section("Water - specular"),
        Item::Row(&[SpecularFactor, SpecularPower]),
        Item::Row(&[SpecularColor]),
        Item::Row(&[AmbientFactor]),
        Item::Section("Water - fresnel"),
        Item::Row(&[FresnelMin, FresnelMax]),
        Item::Row(&[FresnelPower]),
        Item::Row(&[ReflectionDistortion]),
        Item::Section("Water - blur"),
        Item::Row(&[BlurBase, BlurExponent]),
        Item::Section("Water - plane"),
        Item::Row(&[HasWaterPlane, PlaneColor]),
        Item::Section("Water - waves"),
        Item::Row(&[ShoreWaves, FoamTexture]),
        Item::Section("Water - texture"),
        Item::Field(Texture),
        Item::Row(&[RepeatX, RepeatY]),
    ]
}
