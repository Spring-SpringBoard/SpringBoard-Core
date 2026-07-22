use crate::sbc::panels::brush::BrushAction;
use crate::sbc::panels::runtime::Item;

use super::model::GrassField;

pub(crate) const ACTIONS: &[BrushAction] = &[BrushAction {
    caption: "Add",
    image: "LuaUI/images/scenedit/grass-add.png",
    tool: &crate::sbc::grass::brushes::GRASS,
    paint_mode: "",
}];

pub(crate) fn layout() -> Vec<Item<GrassField>> {
    vec![
        Item::Actions,
        Item::Section("Pattern"),
        Item::Grid(GrassField::Pattern),
        Item::Field(GrassField::Detail),
        Item::Field(GrassField::Size),
        Item::Field(GrassField::Rotation),
    ]
}
