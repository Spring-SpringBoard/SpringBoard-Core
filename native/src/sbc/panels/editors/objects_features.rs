use spring_native::prelude::{Error, NativeInterfaceRef};

use crate::sbc::panels::editors::object_defs::{object_defs_editor, DefKind, ObjectDefsView};
use crate::sbc::panels::registry::{EditorSpec, Tab};

// Mirrors FeatureDefsView:Register in scen_edit/view/object/object_defs_view.lua.
inventory::submit! {
    EditorSpec {
        name: "featureDefsView",
        tab: Tab::Objects,
        order: 1,
        caption: "Features",
        tooltip: "Place features",
        image: "LuaUI/images/scenedit/beech.png",
        make: || Box::new(FeatureDefsView::new()),
    }
}

pub(crate) struct FeatureDefsView {
    defs: ObjectDefsView,
}

impl FeatureDefsView {
    pub(crate) fn new() -> Self {
        FeatureDefsView {
            defs: ObjectDefsView::new(DefKind::Feature),
        }
    }
}

object_defs_editor!(FeatureDefsView);
