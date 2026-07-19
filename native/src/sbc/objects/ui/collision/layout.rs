use spring_native::prelude::NativeInterfaceRef;

use crate::sbc::panels::runtime::{EditorModel, Item};
use crate::sbc::rml::element_by_id;

use super::model::ColField::*;
use super::model::{ColField, CollisionModel};

pub(super) fn layout(model: &CollisionModel) -> Vec<Item<ColField>> {
    if model.selected.is_none() {
        return vec![Item::Custom(
            r#"<div class="field-row"><span class="field-label">No object selected.</span></div>"#
                .to_string(),
        )];
    }
    vec![
        Item::Custom(
            r#"<div class="field-row"><button id="collision-show-vol" class="dialog-button" style="width: 200px;">Show volume</button></div>"#
                .to_string(),
        ),
        Item::Field(VType),
        Item::IdField(Axis),
        Item::Section("Scale"),
        Item::IdRow(&[ScaleX, ScaleY, ScaleZ]),
        Item::Section("Offset"),
        Item::IdRow(&[OffsetX, OffsetY, OffsetZ]),
        Item::Section("Radius"),
        Item::IdRow(&[Radius, Height]),
        Item::Section("Center"),
        Item::IdRow(&[MpX, MpY, MpZ]),
        Item::Section("Aim"),
        Item::IdRow(&[ApX, ApY, ApZ]),
        Item::Section("Blocking"),
        // These are one cohesive set of flags. The row keeps the panel
        // compact without squeezing a toggle caption into a third column.
        Item::Row(&[IsBlocking, IsSolidObjectCollidable]),
        Item::Row(&[IsProjectileCollidable, IsRaySegmentCollidable]),
        Item::Row(&[Crushable, BlockEnemyPushing]),
        Item::Row(&[BlockHeightChanges]),
    ]
}

impl CollisionModel {
    /// Toggle the `hidden` class on scale Y/Z and axis wrappers, matching the
    /// Lua `SetInvisibleFields` calls. Called after bind, after refresh, and
    /// when the user changes vType.
    pub(super) fn apply_visibility(&self, interface: &NativeInterfaceRef) {
        let Some(doc) = self.document else {
            return;
        };
        let vtype = self.text(VType);
        let hide_axis = matches!(vtype.as_str(), "Sphere" | "Box");
        let hide_scale_yz = vtype == "Sphere";

        for (name, hide) in [
            ("scaleY", hide_scale_yz),
            ("scaleZ", hide_scale_yz),
            ("axis", hide_axis),
        ] {
            if let Some(elem) = element_by_id(interface, doc, &format!("row-{name}")) {
                let _ = interface.rml_ui().element_set_class(elem, "hidden", hide);
            }
        }
    }

    pub(super) fn write_values(&self, interface: &NativeInterfaceRef) {
        for entry in self.table.fields() {
            let _ = entry.field.write_to_dom(interface);
        }
    }
}
