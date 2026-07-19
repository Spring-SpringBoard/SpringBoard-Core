mod behavior;
mod layout;
mod model;

use crate::sbc::panels::registry::{EditorSpec, Tab};
use crate::sbc::panels::runtime::Runtime;

use behavior::GrassBehavior;
use model::GrassModel;

// Mirrors GrassEditor:Register in scen_edit/view/map/grass_editor.lua.
inventory::submit! {
    EditorSpec {
        name: "grassEditor",
        tab: Tab::Map,
        order: 4,
        caption: "Grass",
        tooltip: "Edit grass",
        image: "LuaUI/images/scenedit/grass.png",
        make: || Box::new(Runtime::new(GrassBehavior, GrassModel::default())),
    }
}
