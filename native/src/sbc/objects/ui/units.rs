use crate::sbc::objects::ui::definitions::{DefKind, ObjectDefsBehavior, ObjectDefsModel};
use crate::sbc::panels::registry::{EditorSpec, Tab};
use crate::sbc::panels::runtime::Runtime;

// Mirrors UnitDefsView:Register in scen_edit/view/object/object_defs_view.lua.
inventory::submit! {
    EditorSpec {
        name: "unitDefsView",
        tab: Tab::Objects,
        order: 0,
        caption: "Units",
        tooltip: "Place units",
        image: "LuaUI/images/scenedit/meeple.png",
        make: || Box::new(Runtime::new(ObjectDefsBehavior, ObjectDefsModel::new(DefKind::Unit))),
    }
}
