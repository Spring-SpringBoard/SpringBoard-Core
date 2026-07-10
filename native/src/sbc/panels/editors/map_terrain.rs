use spring_native::prelude::{Error, NativeInterfaceRef};

use crate::sbc::command_system::model::Models;
use crate::sbc::panels::editor::Editor;
use crate::sbc::panels::editor_base::FieldSet;
use crate::sbc::panels::editors::brush::{
    brush_editor_boilerplate, non_empty, pattern_field, BrushAction, BrushActions,
};
use crate::sbc::panels::field::{ChangeQueue, FieldValue, InteractionQueue};
use crate::sbc::panels::fields::{ChoiceField, NumericField};
use crate::sbc::panels::registry::{EditorSpec, Tab};
use crate::sbc::states::{ApplyDir, BrushKind, BrushSettings};

// Mirrors HeightmapEditor:Register in scen_edit/view/map/heightmap_editor.lua.
inventory::submit! {
    EditorSpec {
        name: "heightmapEditor",
        tab: Tab::Map,
        order: 1,
        caption: "Terrain",
        tooltip: "Edit terrain height",
        image: "LuaUI/images/scenedit/peaks.png",
        make: || Box::new(TerrainEditor::new()),
    }
}

/// The three height brushes, as in Lua's Add / Set / Smooth buttons.
const ACTIONS: &[BrushAction] = &[
    BrushAction {
        caption: "Add",
        kind: BrushKind::ShapeModify,
    },
    BrushAction {
        caption: "Set",
        kind: BrushKind::Level,
    },
    BrushAction {
        caption: "Smooth",
        kind: BrushKind::Smooth,
    },
];

/// The height brush: shape, size, rotation and how hard it pushes.
pub(crate) struct TerrainEditor {
    fields: FieldSet,
    actions: BrushActions,
}

impl TerrainEditor {
    pub(crate) fn new() -> Self {
        TerrainEditor {
            fields: FieldSet::new(vec![
                pattern_field(),
                Box::new(
                    NumericField::new("size", "Size", 100.0)
                        .min(10.0)
                        .max(5000.0),
                ),
                Box::new(
                    NumericField::new("rotation", "Rotation", 0.0)
                        .min(-360.0)
                        .max(360.0),
                ),
                Box::new(
                    NumericField::new("strength", "Strength", 10.0)
                        .step(0.1)
                        .decimals(1),
                ),
                Box::new(
                    NumericField::new("height", "Height", 10.0)
                        .step(0.1)
                        .decimals(1),
                ),
                Box::new(ChoiceField::new(
                    "applyDir",
                    "Direction",
                    vec![
                        "Both".to_string(),
                        "Only Raise".to_string(),
                        "Only Lower".to_string(),
                    ],
                )),
            ]),
            actions: BrushActions::new(ACTIONS),
        }
    }
}

impl Editor for TerrainEditor {
    fn generate_rml(&self) -> String {
        let mut h = self.actions.generate_rml();
        for name in [
            "patternTexture",
            "size",
            "rotation",
            "strength",
            "height",
            "applyDir",
        ] {
            h.push_str(&self.fields.rml(name));
        }
        h
    }

    fn refresh_from_engine(&mut self, _interface: &NativeInterfaceRef, _models: &mut Models) {}

    fn write_brush(&self, brush: &mut BrushSettings) {
        brush.size = self.fields.number("size");
        brush.rotation = self.fields.number("rotation");
        brush.strength = self.fields.number("strength");
        brush.height = self.fields.number("height");
        brush.apply_dir = ApplyDir::from_caption(&self.fields.text("applyDir"));
        brush.pattern_texture = non_empty(self.fields.text("patternTexture"));
    }

    /// A wheel resize or a right-clicked target height happened on the map; show
    /// it in the fields.
    fn read_brush(&mut self, brush: &BrushSettings, interface: &NativeInterfaceRef) {
        self.fields.set("size", FieldValue::Number(brush.size));
        self.fields
            .set("rotation", FieldValue::Number(brush.rotation));
        self.fields.set("height", FieldValue::Number(brush.height));
        let _ = self.fields.write_values(interface);
    }

    brush_editor_boilerplate!();
}
