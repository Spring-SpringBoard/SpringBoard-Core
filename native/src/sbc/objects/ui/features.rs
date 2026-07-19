use crate::sbc::objects::ui::definitions::{DefKind, ObjectDefsBehavior, ObjectDefsModel};
use crate::sbc::panels::registry::{EditorSpec, Tab};
use crate::sbc::panels::runtime::Runtime;

// Mirrors FeatureDefsView:Register in scen_edit/view/object/object_defs_view.lua.
inventory::submit! {
    EditorSpec {
        name: "featureDefsView",
        tab: Tab::Objects,
        order: 1,
        caption: "Features",
        tooltip: "Place features",
        image: "LuaUI/images/scenedit/beech.png",
        make: || Box::new(Runtime::new(
            ObjectDefsBehavior,
            ObjectDefsModel::new(DefKind::Feature),
        )),
    }
}
