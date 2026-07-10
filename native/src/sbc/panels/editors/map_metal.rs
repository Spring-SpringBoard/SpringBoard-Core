use spring_native::prelude::{Error, NativeInterfaceRef};

use crate::sbc::command_system::model::Models;
use crate::sbc::panels::editor::Editor;
use crate::sbc::panels::editor_base::FieldSet;
use crate::sbc::panels::editors::brush::{brush_editor_boilerplate, pattern_field};
use crate::sbc::panels::field::{ChangeQueue, FieldValue, InteractionQueue};
use crate::sbc::panels::fields::NumericField;
use crate::sbc::panels::registry::{EditorSpec, Tab};

// Mirrors MetalEditor:Register in scen_edit/view/map/metal_editor.lua.
inventory::submit! {
    EditorSpec {
        name: "metalEditor",
        tab: Tab::Map,
        order: 3,
        caption: "Metal",
        tooltip: "Edit metal map",
        image: "LuaUI/images/scenedit/minerals.png",
        make: || Box::new(MetalEditor::new()),
    }
}

/// The metal brush.
pub(crate) struct MetalEditor {
    fields: FieldSet,
}

impl MetalEditor {
    pub(crate) fn new() -> Self {
        MetalEditor {
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
                    NumericField::new("amount", "Amount", 50.0)
                        .min(0.0)
                        .max(5.1)
                        .decimals(2),
                ),
            ]),
        }
    }
}

impl Editor for MetalEditor {
    fn generate_rml(&self) -> String {
        ["patternTexture", "size", "rotation", "amount"]
            .iter()
            .map(|n| self.fields.rml(n))
            .collect()
    }

    fn refresh_from_engine(&mut self, _interface: &NativeInterfaceRef, _models: &mut Models) {}

    brush_editor_boilerplate!();
}
