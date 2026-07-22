use crate::sbc::panels::brush::BrushAction;
use crate::sbc::panels::runtime::Item;

use super::model::MetalField;

pub(crate) const ACTIONS: &[BrushAction] = &[BrushAction {
    caption: "Set",
    image: "LuaUI/images/scenedit/metal-add.png",
    tool: &crate::sbc::metal::brushes::METAL,
    paint_mode: "",
}];

pub(crate) fn layout() -> Vec<Item<MetalField>> {
    vec![
        Item::Actions,
        Item::Section("Pattern"),
        Item::Grid(MetalField::Pattern),
        Item::Field(MetalField::Size),
        Item::Field(MetalField::Rotation),
        Item::Field(MetalField::Amount),
    ]
}
