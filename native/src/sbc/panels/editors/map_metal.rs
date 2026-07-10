use spring_native::prelude::{Error, NativeInterfaceRef};

use crate::sbc::command_system::model::Models;
use crate::sbc::panels::editor::Editor;
use crate::sbc::panels::editor_base::FieldSet;
use crate::sbc::panels::editors::brush::{
    brush_editor_boilerplate, non_empty, pattern_field, BrushAction, BrushActions,
};
use crate::sbc::panels::field::{ChangeQueue, FieldValue, InteractionQueue};
use crate::sbc::panels::fields::NumericField;
use crate::sbc::panels::registry::{EditorSpec, Tab};
use crate::sbc::states::{BrushKind, BrushSettings};

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

const ACTIONS: &[BrushAction] = &[BrushAction {
    caption: "Set",
    kind: BrushKind::Metal,
}];

/// The metal brush.
pub(crate) struct MetalEditor {
    fields: FieldSet,
    actions: BrushActions,
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
            actions: BrushActions::new(ACTIONS),
        }
    }
}

impl Editor for MetalEditor {
    fn generate_rml(&self) -> String {
        let mut h = self.actions.generate_rml();
        for name in ["patternTexture", "size", "rotation", "amount"] {
            h.push_str(&self.fields.rml(name));
        }
        h
    }

    fn refresh_from_engine(&mut self, _interface: &NativeInterfaceRef, _models: &mut Models) {}

    fn write_brush(&self, brush: &mut BrushSettings) {
        brush.size = self.fields.number("size");
        brush.rotation = self.fields.number("rotation");
        brush.amount = self.fields.number("amount");
        brush.pattern_texture = non_empty(self.fields.text("patternTexture"));
    }

    fn read_brush(&mut self, brush: &BrushSettings, interface: &NativeInterfaceRef) {
        self.fields.set("size", FieldValue::Number(brush.size));
        self.fields
            .set("rotation", FieldValue::Number(brush.rotation));
        let _ = self.fields.write_values(interface);
    }

    brush_editor_boilerplate!();
}
