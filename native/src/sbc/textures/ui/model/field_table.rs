//! Texture brush field definitions and their static asset grid.

use super::{enabled_name, TexField, DNTS_COUNT};
use crate::sbc::panels::fields::{BooleanField, ChoiceField, ColorField, NumericField};
use crate::sbc::panels::runtime::{AssetGridDef, Brush, TableEntry, TableModel};
use crate::sbc::textures::materials::CHANNELS;

use TexField::*;

/// Blend modes, in the order `texture_editor.lua` lists them.
const MODES: &[&str] = &[
    "Normal",
    "Darken",
    "Lighten",
    "SoftLight",
    "HardLight",
    "Luminance",
    "Multiply",
    "Premultiplied",
    "Overlay",
    "Screen",
    "Add",
    "Subtract",
    "Difference",
    "InverseDifference",
    "Exclusion",
    "Color",
    "ColorBurn",
    "ColorDodge",
];

const KERNELS: &[&str] = &[
    "blur",
    "bottom_sobel",
    "emboss",
    "left_sobel",
    "outline",
    "right_sobel",
    "sharpen",
    "top sobel",
];

static PATTERN: AssetGridDef = AssetGridDef {
    name: "patternTexture",
    container: "texture-pattern-grid",
    root: "brush_patterns/terrain/",
    extensions: &["png", "jpg", "tga", "dds", "bmp"],
    cell: 64,
    brush: Some(Brush::Pattern),
};

pub(super) fn texture_table() -> TableModel<TexField> {
    let mut entries = vec![
        TableEntry {
            id: Size,
            field: Box::new(
                NumericField::new("size", "Size", 100.0)
                    .min(1.0)
                    .max(5000.0),
            ),
            brush: Some(Brush::Size),
        },
        TableEntry {
            id: Rotation,
            field: Box::new(
                NumericField::new("rotation", "Rotation", 0.0)
                    .min(-360.0)
                    .max(360.0),
            ),
            brush: Some(Brush::Rotation),
        },
        TableEntry::new(
            TexScale,
            Box::new(
                NumericField::new("texScale", "Scale", 2.0)
                    .min(0.01)
                    .step(0.05)
                    .decimals(2),
            ),
        ),
        TableEntry::new(
            TexRotation,
            Box::new(
                NumericField::new("texRotation", "Tex rotation", 0.0)
                    .min(-360.0)
                    .max(360.0),
            ),
        ),
        TableEntry::new(
            TexOffsetX,
            Box::new(
                NumericField::new("texOffsetX", "X", 0.0)
                    .min(-1.0)
                    .max(1.0)
                    .step(0.001)
                    .decimals(3),
            ),
        ),
        TableEntry::new(
            TexOffsetY,
            Box::new(
                NumericField::new("texOffsetY", "Y", 0.0)
                    .min(-1.0)
                    .max(1.0)
                    .step(0.001)
                    .decimals(3),
            ),
        ),
        TableEntry::new(
            Mode,
            Box::new(ChoiceField::new("mode", "Mode", items(MODES))),
        ),
        TableEntry::new(
            KernelMode,
            Box::new(ChoiceField::new("kernelMode", "Filter", items(KERNELS))),
        ),
        TableEntry::new(
            Strength,
            Box::new(
                NumericField::new("strength", "Strength", 1.0)
                    .min(0.0)
                    .max(1.0)
                    .step(0.05)
                    .decimals(2),
            ),
        ),
        TableEntry::new(
            FalloffFactor,
            Box::new(
                NumericField::new("falloffFactor", "Falloff", 0.3)
                    .min(0.0)
                    .max(1.0)
                    .step(0.05)
                    .decimals(2),
            ),
        ),
        TableEntry::new(
            FeatureFactor,
            Box::new(
                NumericField::new("featureFactor", "Feature", 1.0)
                    .min(0.0)
                    .max(1.0)
                    .step(0.05)
                    .decimals(2),
            ),
        ),
        TableEntry::new(
            Value,
            Box::new(
                NumericField::new("value", "Value", 1.0)
                    .min(0.0)
                    .max(1.0)
                    .step(0.05)
                    .decimals(2),
            ),
        ),
        TableEntry::new(
            VoidFactor,
            Box::new(
                NumericField::new("voidFactor", "Transparency", 1.0)
                    .min(0.0)
                    .max(1.0)
                    .step(0.05)
                    .decimals(2),
            ),
        ),
        TableEntry::new(
            SplatTexScale,
            Box::new(
                NumericField::new("splatTexScale", "Scale", 1.0)
                    .step(0.000_001)
                    .decimals(6),
            ),
        ),
        TableEntry::new(
            SplatTexMult,
            Box::new(
                NumericField::new("splatTexMult", "Mult", 0.5)
                    .step(0.01)
                    .decimals(2),
            ),
        ),
        TableEntry::new(
            DntsIndex,
            Box::new(
                NumericField::new("dntsIndex", "DNTS", 0.0)
                    .min(0.0)
                    .max((DNTS_COUNT - 1) as f32)
                    .decimals(0),
            ),
        ),
        TableEntry::new(
            Exclusive,
            Box::new(BooleanField::new("exclusive", "Exclusive", false)),
        ),
        TableEntry::new(
            DiffuseColor,
            Box::new(ColorField::new("diffuseColor", "Color")),
        ),
    ];
    for (channel, title, toggle) in CHANNELS {
        if !toggle {
            continue;
        }
        let id = match *channel {
            "diffuse" => DiffuseEnabled,
            "specular" => SpecularEnabled,
            "emission" => EmissionEnabled,
            _ => ReflEnabled,
        };
        entries.push(TableEntry::new(
            id,
            Box::new(BooleanField::new(&enabled_name(channel), title, true)),
        ));
    }
    TableModel::new(entries)
}

pub(super) fn pattern() -> &'static AssetGridDef {
    &PATTERN
}

fn items(values: &[&str]) -> Vec<String> {
    values.iter().map(|v| v.to_string()).collect()
}
