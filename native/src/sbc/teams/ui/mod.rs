mod behavior;
mod layout;
mod model;

use crate::sbc::panels::registry::{EditorSpec, Tab};
use crate::sbc::panels::runtime::Runtime;

use behavior::TeamsBehavior;
use model::TeamsModel;

inventory::submit! {
    EditorSpec {
        name: "teamsView",
        tab: Tab::Misc,
        order: 1,
        caption: "Teams",
        tooltip: "Edit teams",
        image: "LuaUI/images/scenedit/person.png",
        make: || Box::new(Runtime::new(TeamsBehavior, TeamsModel::new())),
    }
}
