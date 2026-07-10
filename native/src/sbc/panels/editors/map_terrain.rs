use spring_native::prelude::{Error, NativeInterfaceRef};

use crate::sbc::command_system::model::Models;
use crate::sbc::panels::editor::Editor;
use crate::sbc::panels::editor_base::FieldSet;
use crate::sbc::panels::editors::brush::{brush_editor_boilerplate, pattern_field};
use crate::sbc::panels::field::{ChangeQueue, FieldValue, InteractionQueue};
use crate::sbc::panels::fields::{ChoiceField, NumericField};
use crate::sbc::panels::registry::{EditorSpec, Tab};

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

/// The height brush: shape, size, rotation and how hard it pushes.
pub(crate) struct TerrainEditor {
    fields: FieldSet,
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
        }
    }
}

impl Editor for TerrainEditor {
    fn generate_rml(&self) -> String {
        [
            "patternTexture",
            "size",
            "rotation",
            "strength",
            "height",
            "applyDir",
        ]
        .iter()
        .map(|n| self.fields.rml(n))
        .collect()
    }

    fn refresh_from_engine(&mut self, _interface: &NativeInterfaceRef, _models: &mut Models) {}

    brush_editor_boilerplate!();
}
