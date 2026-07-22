use crate::sbc::panels::brush::BrushAction;
use crate::sbc::panels::runtime::Item;

use super::model::TerrainField;

/// The three height brushes, as in Lua's Add / Set / Smooth buttons.
pub(crate) const ACTIONS: &[BrushAction] = &[
    BrushAction {
        caption: "Add",
        image: "LuaUI/images/scenedit/up-card.png",
        tool: &crate::sbc::heightmap::brushes::SHAPE_MODIFY,
        paint_mode: "",
    },
    BrushAction {
        caption: "Set",
        image: "LuaUI/images/scenedit/terrain-set.png",
        tool: &crate::sbc::heightmap::brushes::LEVEL,
        paint_mode: "",
    },
    BrushAction {
        caption: "Smooth",
        image: "LuaUI/images/scenedit/terrain-smooth.png",
        tool: &crate::sbc::heightmap::brushes::SMOOTH,
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
