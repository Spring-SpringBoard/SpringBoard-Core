mod behavior;
mod layout;
mod model;

use crate::sbc::panels::registry::{EditorSpec, Tab};
use crate::sbc::panels::runtime::Runtime;

use behavior::InfoBehavior;
use model::info_model;

// Mirrors ScenarioInfoView:Register in scen_edit/view/general/scenario_info_view.lua.
inventory::submit! {
    EditorSpec {
        name: "scenarioInfoView",
        tab: Tab::Misc,
        order: 0,
        caption: "Info",
        tooltip: "Edit project info",
        image: "LuaUI/images/scenedit/info.png",
        make: || Box::new(Runtime::new(InfoBehavior, info_model())),
    }
}
