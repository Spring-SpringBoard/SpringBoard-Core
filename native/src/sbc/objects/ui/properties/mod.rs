mod behavior;
mod layout;
mod model;

use crate::sbc::panels::registry::{EditorSpec, Tab};
use crate::sbc::panels::runtime::Runtime;

use behavior::PropertiesBehavior;
use model::PropertiesModel;

// Mirrors ObjectPropertyWindow:Register in scen_edit/view/object/object_property_window.lua.
inventory::submit! {
    EditorSpec {
        name: "objectPropertyWindow",
        tab: Tab::Objects,
        order: 2,
        caption: "Properties",
        tooltip: "Edit object properties",
        image: "LuaUI/images/scenedit/anatomy.png",
        make: || Box::new(Runtime::new(PropertiesBehavior, PropertiesModel::new())),
    }
}
