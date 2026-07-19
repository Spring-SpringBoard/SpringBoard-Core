use crate::sbc::panels::field::Field;
use crate::sbc::panels::fields::{AssetField, BooleanField, ColorField, NumericField};
use crate::sbc::panels::runtime::{TableEntry, TableModel};

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub(crate) enum WaterField {
    ForceRendering,
    NumTiles,
    PerlinStartFreq,
    PerlinLacunarity,
    PerlinAmplitude,
    DiffuseFactor,
    DiffuseColor,
    SpecularFactor,
    SpecularPower,
    SpecularColor,
    AmbientFactor,
    FresnelMin,
    FresnelMax,
    FresnelPower,
    ReflectionDistortion,
    BlurBase,
    BlurExponent,
    HasWaterPlane,
    PlaneColor,
    ShoreWaves,
    RepeatX,
    RepeatY,
    NormalTexture,
    FoamTexture,
    Texture,
}

use WaterField::*;

fn num(name: &'static str, title: &'static str) -> Box<NumericField> {
    Box::new(NumericField::new(name, title, 0.0).decimals(2))
}

/// Water textures live under the engine VFS's `bitmaps/`, as in
/// `water_editor.lua` — that is engine content, not an asset pack, so the
/// picker browses the VFS directly.
fn tex(name: &'static str, title: &'static str) -> Box<AssetField> {
    Box::new(
        AssetField::new(name, title, "vfs:bitmaps")
            .extensions(&[".png", ".jpg", ".tga", ".dds", ".bmp"]),
    )
}

/// Every field here is a key of `SetWaterParamsCommand`'s options, so the
/// dispatch is uniform: send the one field that changed.
///
/// Texture fields pick a path from the VFS with the asset picker; the command
/// applies them through the engine's dedicated water-texture binding.
pub(crate) fn water_model() -> TableModel<WaterField> {
    let entry = |id, field: Box<dyn Field>| TableEntry::new(id, field);
    TableModel::new(vec![
        entry(
            ForceRendering,
            Box::new(BooleanField::new(
                "forceRendering",
                "Forced rendering",
                false,
            )),
        ),
        entry(NumTiles, num("numTiles", "NumTiles")),
        entry(PerlinStartFreq, num("perlinStartFreq", "Start freq")),
        entry(PerlinLacunarity, num("perlinLacunarity", "Lacunarity")),
        entry(PerlinAmplitude, num("perlinAmplitude", "Amplitude")),
        entry(DiffuseFactor, num("diffuseFactor", "Factor")),
        entry(
            DiffuseColor,
            Box::new(ColorField::new("diffuseColor", "Diffuse color")),
        ),
        entry(SpecularFactor, num("specularFactor", "Factor")),
        entry(SpecularPower, num("specularPower", "Power")),
        entry(
            SpecularColor,
            Box::new(ColorField::new("specularColor", "Color")),
        ),
        entry(AmbientFactor, num("ambientFactor", "Ambient factor")),
        entry(FresnelMin, num("fresnelMin", "Min")),
        entry(FresnelMax, num("fresnelMax", "Max")),
        entry(FresnelPower, num("fresnelPower", "Power")),
        entry(
            ReflectionDistortion,
            num("reflectionDistortion", "Reflection distortion"),
        ),
        entry(BlurBase, num("blurBase", "Base")),
        entry(BlurExponent, num("blurExponent", "Exponent")),
        entry(
            HasWaterPlane,
            Box::new(BooleanField::new("hasWaterPlane", "Enabled", false)),
        ),
        entry(PlaneColor, Box::new(ColorField::new("planeColor", "Color"))),
        entry(
            ShoreWaves,
            Box::new(BooleanField::new("shoreWaves", "Enabled", false)),
        ),
        entry(RepeatX, num("repeatX", "Repeat X")),
        entry(RepeatY, num("repeatY", "Repeat Y")),
        entry(NormalTexture, tex("normalTexture", "Normal texture")),
        entry(FoamTexture, tex("foamTexture", "Foam texture")),
        entry(Texture, tex("texture", "Texture")),
    ])
}
