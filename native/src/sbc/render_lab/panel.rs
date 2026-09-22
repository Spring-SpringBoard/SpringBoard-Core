use crate::sbc::panels::registry::{EditorSpec, Tab};
use crate::sbc::panels::runtime::Runtime;

use super::behavior::LabBehavior;
use super::model::LabModel;

inventory::submit! {
    EditorSpec {
        name: "renderLab",
        tab: Tab::Env,
        order: 5,
        caption: "Rendering Lab",
        tooltip: "Switch, solo, inspect and explain what the renderer does",
        image: "LuaUI/images/scenedit/sunbeams.png",
        make: || Box::new(Runtime::new(LabBehavior::default(), LabModel::default())),
    }
}
