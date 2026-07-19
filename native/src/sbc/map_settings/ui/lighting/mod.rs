mod behavior;
mod layout;
mod model;

use crate::sbc::panels::registry::{EditorSpec, Tab};
use crate::sbc::panels::runtime::Runtime;

use behavior::LightingBehavior;
use model::lighting_model;

// Mirrors LightingEditor:Register in scen_edit/view/map/lighting_editor.lua.
inventory::submit! {
    EditorSpec {
        name: "lightingEditor",
        tab: Tab::Env,
        order: 0,
        caption: "Lighting",
        tooltip: "Edit lighting",
        image: "LuaUI/images/scenedit/sunbeams.png",
        make: || Box::new(Runtime::new(LightingBehavior, lighting_model())),
    }
}
