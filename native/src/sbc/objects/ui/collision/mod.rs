mod behavior;
mod layout;
mod model;

use crate::sbc::panels::registry::{EditorSpec, Tab};
use crate::sbc::panels::runtime::Runtime;

use behavior::CollisionBehavior;
use model::CollisionModel;

// Mirrors CollisionView:Register in scen_edit/view/object/collision_window.lua.
inventory::submit! {
    EditorSpec {
        name: "collisionView",
        tab: Tab::Objects,
        order: 3,
        caption: "Collision",
        tooltip: "Edit collision volumes",
        image: "LuaUI/images/scenedit/boulder-dash.png",
        make: || Box::new(Runtime::new(CollisionBehavior, CollisionModel::new())),
    }
}
