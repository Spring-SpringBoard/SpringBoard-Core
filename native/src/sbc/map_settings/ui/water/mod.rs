mod behavior;
mod layout;
mod model;

use crate::sbc::panels::registry::{EditorSpec, Tab};
use crate::sbc::panels::runtime::Runtime;

use behavior::WaterBehavior;
use model::water_model;

// Mirrors WaterEditor:Register in scen_edit/view/map/water_editor.lua.
inventory::submit! {
    EditorSpec {
        name: "waterEditor",
        tab: Tab::Env,
        order: 2,
        caption: "Water",
        tooltip: "Edit water",
        image: "LuaUI/images/scenedit/wave-crest.png",
        make: || Box::new(Runtime::new(WaterBehavior, water_model())),
    }
}
