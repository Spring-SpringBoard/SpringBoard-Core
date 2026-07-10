use spring_native::prelude::{Error, NativeInterfaceRef};

use crate::sbc::command_system::model::Models;
use crate::sbc::panels::editor::Editor;
use crate::sbc::panels::editor_base::{group_rml, section_rml, FieldSet};
use crate::sbc::panels::editors::brush::{
    brush_editor_boilerplate, non_empty, pattern_field, BrushAction, BrushActions, ASSETS,
};
use crate::sbc::panels::field::{ChangeQueue, FieldValue, InteractionQueue};
use crate::sbc::panels::fields::{AssetField, BooleanField, ChoiceField, NumericField};
use crate::sbc::panels::registry::{EditorSpec, Tab};
use crate::sbc::states::{BrushKind, BrushSettings};

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

/// Lua also has Filter, DNTS and Void buttons. Only Paint is here: the others
/// need the material model and the DNTS index the picker would provide.
const ACTIONS: &[BrushAction] = &[BrushAction {
    caption: "Paint",
    kind: BrushKind::Texture,
}];

/// The texture brush. The material picker (Lua's `mapMaterials`) is not ported:
/// it needs a material model, not another grid, so only the diffuse channel of
/// the chosen brush texture is painted.
pub(crate) struct TextureEditor {
    fields: FieldSet,
    actions: BrushActions,
}

fn items(values: &[&str]) -> Vec<String> {
    values.iter().map(|v| v.to_string()).collect()
}

impl TextureEditor {
    pub(crate) fn new() -> Self {
        TextureEditor {
            actions: BrushActions::new(ACTIONS),
            fields: FieldSet::new(vec![
                pattern_field(),
                Box::new(
                    AssetField::new(
                        "brushTexture",
                        "Texture",
                        &format!("{ASSETS}/brush_textures"),
                    )
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
        let mut h = self.actions.generate_rml();
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

    fn write_brush(&self, brush: &mut BrushSettings) {
        brush.size = self.fields.number("size");
        brush.rotation = self.fields.number("rotation");
        brush.tex_scale = self.fields.number("texScale");
        brush.mode = self.fields.text("mode");
        brush.pattern_texture = non_empty(self.fields.text("patternTexture"));
        brush.brush_texture = non_empty(self.fields.text("brushTexture"));
    }

    fn read_brush(&mut self, brush: &BrushSettings, interface: &NativeInterfaceRef) {
        self.fields.set("size", FieldValue::Number(brush.size));
        self.fields
            .set("rotation", FieldValue::Number(brush.rotation));
        let _ = self.fields.write_values(interface);
    }

    brush_editor_boilerplate!();
}
