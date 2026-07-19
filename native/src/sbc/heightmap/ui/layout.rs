use crate::sbc::panels::brush::BrushAction;
use crate::sbc::panels::runtime::Item;
use crate::sbc::states::BrushKind;

use super::model::TerrainField;

/// The three height brushes, as in Lua's Add / Set / Smooth buttons.
pub(crate) const ACTIONS: &[BrushAction] = &[
    BrushAction {
        caption: "Add",
        image: "LuaUI/images/scenedit/up-card.png",
        kind: BrushKind::ShapeModify,
        paint_mode: "",
    },
    BrushAction {
        caption: "Set",
        image: "LuaUI/images/scenedit/terrain-set.png",
        kind: BrushKind::Level,
        paint_mode: "",
    },
    BrushAction {
        caption: "Smooth",
        image: "LuaUI/images/scenedit/terrain-smooth.png",
        kind: BrushKind::Smooth,
        paint_mode: "",
    },
];

pub(crate) fn layout() -> Vec<Item<TerrainField>> {
    vec![
        Item::Actions,
        Item::Grid(TerrainField::Pattern),
        Item::Field(TerrainField::Size),
        Item::Field(TerrainField::Rotation),
        Item::Field(TerrainField::Strength),
        Item::Field(TerrainField::Height),
        Item::Field(TerrainField::ApplyDir),
    ]
}
