mod behavior;
mod layout;
mod model;

use crate::sbc::panels::registry::{EditorSpec, Tab};
use crate::sbc::panels::runtime::Runtime;

use behavior::MetalBehavior;
use model::MetalModel;

// Mirrors MetalEditor:Register in scen_edit/view/map/metal_editor.lua.
inventory::submit! {
    EditorSpec {
        name: "metalEditor",
        tab: Tab::Map,
        order: 3,
        caption: "Metal",
        tooltip: "Edit metal map",
        image: "LuaUI/images/scenedit/minerals.png",
        make: || Box::new(Runtime::new(MetalBehavior, MetalModel::default())),
    }
}
