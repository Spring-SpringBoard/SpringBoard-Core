use spring_native::prelude::{Error, NativeInterfaceRef};

use crate::sbc::command_system::model::Models;
use crate::sbc::panels::editor::Editor;
use crate::sbc::panels::editor_base::{group_rml, section_rml, FieldSet};
use crate::sbc::panels::editors::brush::{brush_editor_boilerplate, pattern_field};
use crate::sbc::panels::field::{ChangeQueue, FieldValue, InteractionQueue};
use crate::sbc::panels::fields::{AssetField, BooleanField, ChoiceField, NumericField};
use crate::sbc::panels::registry::{EditorSpec, Tab};

// Mirrors TextureEditor:Register in scen_edit/view/map/texture_editor.lua.
inventory::submit! {
    EditorSpec {
        name: "textureEditor",
        tab: Tab::Map,
        order: 2,
        caption: "Texture",
        tooltip: "Edit map texture",
        image: "LuaUI/images/scenedit/palette.png",
        make: || Box::new(TextureEditor::new()),
    }
}

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

/// The texture brush. The material picker (Lua's `mapMaterials`) is not ported:
/// it needs a material model, not another grid.
pub(crate) struct TextureEditor {
    fields: FieldSet,
}

fn items(values: &[&str]) -> Vec<String> {
    values.iter().map(|v| v.to_string()).collect()
}

impl TextureEditor {
    pub(crate) fn new() -> Self {
        TextureEditor {
            fields: FieldSet::new(vec![
                pattern_field(),
                Box::new(
                    AssetField::new("brushTexture", "Texture", "brush_textures")
                        .extensions(&[".png", ".jpg", ".tga", ".dds", ".bmp"]),
                ),
                Box::new(ChoiceField::new("mode", "Mode", items(MODES))),
                Box::new(ChoiceField::new("kernelMode", "Filter", items(KERNELS))),
                Box::new(BooleanField::new("exclusive", "Exclusive", false)),
                Box::new(
                    NumericField::new("size", "Size", 100.0)
                        .min(1.0)
                        .max(5000.0),
                ),
                Box::new(
                    NumericField::new("rotation", "Rotation", 0.0)
                        .min(-360.0)
                        .max(360.0),
                ),
                Box::new(
                    NumericField::new("texScale", "Scale", 2.0)
                        .min(0.01)
                        .step(0.05)
                        .decimals(2),
                ),
            ]),
        }
    }
}

impl Editor for TextureEditor {
    fn generate_rml(&self) -> String {
        let mut h = String::new();
        h.push_str(&self.fields.rml("patternTexture"));
        h.push_str(&self.fields.rml("brushTexture"));
        h.push_str(&self.fields.rml("mode"));
        h.push_str(&self.fields.rml("kernelMode"));
        h.push_str(&self.fields.rml("exclusive"));
        h.push_str(&section_rml("Brush"));
        h.push_str(&group_rml(&[
            self.fields.rml("size"),
            self.fields.rml("rotation"),
        ]));
        h.push_str(&group_rml(&[self.fields.rml("texScale")]));
        h
    }

    fn refresh_from_engine(&mut self, _interface: &NativeInterfaceRef, _models: &mut Models) {}

    brush_editor_boilerplate!();
}
