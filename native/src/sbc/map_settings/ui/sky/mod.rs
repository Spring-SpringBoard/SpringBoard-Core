mod behavior;
mod layout;
mod model;

use crate::sbc::panels::registry::{EditorSpec, Tab};
use crate::sbc::panels::runtime::Runtime;

use behavior::SkyBehavior;
use model::sky_model;

// Mirrors SkyEditor:Register in scen_edit/view/map/sky_editor.lua.
inventory::submit! {
    EditorSpec {
        name: "skyEditor",
        tab: Tab::Env,
        order: 1,
        caption: "Sky",
        tooltip: "Edit sky and fog",
        image: "LuaUI/images/scenedit/night-sky.png",
        make: || Box::new(Runtime::new(SkyBehavior, sky_model())),
    }
}
