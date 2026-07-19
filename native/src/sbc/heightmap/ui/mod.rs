mod behavior;
mod layout;
mod model;

use crate::sbc::panels::registry::{EditorSpec, Tab};
use crate::sbc::panels::runtime::Runtime;

use behavior::TerrainBehavior;
use model::TerrainModel;

// Mirrors HeightmapEditor:Register in scen_edit/view/map/heightmap_editor.lua.
inventory::submit! {
    EditorSpec {
        name: "heightmapEditor",
        tab: Tab::Map,
        order: 1,
        caption: "Terrain",
        tooltip: "Edit terrain height",
        image: "LuaUI/images/scenedit/peaks.png",
        make: || Box::new(Runtime::new(TerrainBehavior, TerrainModel::default())),
    }
}
