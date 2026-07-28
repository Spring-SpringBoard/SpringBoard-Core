use spring_native::prelude::NativeInterfaceRef;

use crate::sbc::panels::runtime::{EditorModel, Item};

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
    pub(super) fn write_values(&self, interface: &NativeInterfaceRef) {
        for entry in self.table.fields() {
            let _ = entry.field.write_to_dom(interface);
        }
    }
}
