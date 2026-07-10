use spring_native::prelude::{Error, NativeInterfaceRef};

use crate::sbc::panels::editors::object_defs::{object_defs_editor, DefKind, ObjectDefsView};
use crate::sbc::panels::registry::{EditorSpec, Tab};

// Mirrors UnitDefsView:Register in scen_edit/view/object/object_defs_view.lua.
inventory::submit! {
    EditorSpec {
        name: "unitDefsView",
        tab: Tab::Objects,
        order: 0,
        caption: "Units",
        tooltip: "Place units",
        image: "LuaUI/images/scenedit/meeple.png",
        make: || Box::new(UnitDefsView::new()),
    }
}

pub(crate) struct UnitDefsView {
    defs: ObjectDefsView,
}

impl UnitDefsView {
    pub(crate) fn new() -> Self {
        UnitDefsView {
            defs: ObjectDefsView::new(DefKind::Unit),
        }
    }
}

object_defs_editor!(UnitDefsView);
