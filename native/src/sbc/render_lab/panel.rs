use crate::sbc::panels::registry::{EditorSpec, Tab};
use crate::sbc::panels::runtime::Runtime;

use super::behavior::LabBehavior;
use super::model::LabModel;

/// The panels of the Effects tab, by the name a renderer's categories and scenes give them.
pub(crate) const STAGES_PANEL: &str = "stages";
pub(crate) const FIRE_PANEL: &str = "fire";
pub(crate) const TUNING_PANEL: &str = "tuning";
pub(crate) const RUNTIME_PANEL: &str = "runtime";
pub(crate) const EFFECTS_PANELS: [&str; 4] = [STAGES_PANEL, FIRE_PANEL, TUNING_PANEL, RUNTIME_PANEL];

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

inventory::submit! {
    EditorSpec {
        name: "effectsStages",
        tab: Tab::Effects,
        order: 1,
        caption: "Stages",
        tooltip: "Play a staged fight, flight or death; fire its weapons",
        image: "LuaUI/images/scenedit/play-button.png",
        make: || Box::new(Runtime::new(LabBehavior::default(), LabModel::for_panel(STAGES_PANEL))),
    }
}

inventory::submit! {
    EditorSpec {
        name: "effectsFire",
        tab: Tab::Effects,
        order: 2,
        caption: "Fire",
        tooltip: "Set off one effect at the stage, or ahead of the camera",
        image: "LuaUI/images/scenedit/omega.png",
        make: || Box::new(Runtime::new(LabBehavior::default(), LabModel::for_panel(FIRE_PANEL))),
    }
}

inventory::submit! {
    EditorSpec {
        name: "effectsTuning",
        tab: Tab::Effects,
        order: 3,
        caption: "Tuning",
        tooltip: "Switch effects on and off and scale how they look",
        image: "LuaUI/images/scenedit/cog.png",
        make: || Box::new(Runtime::new(LabBehavior::default(), LabModel::for_panel(TUNING_PANEL))),
    }
}

inventory::submit! {
    EditorSpec {
        name: "effectsRuntime",
        tab: Tab::Effects,
        order: 4,
        caption: "GPU particles",
        tooltip: "Step through how the GPU particles are drawn, measure them, stress them",
        image: "LuaUI/images/scenedit/computing.png",
        make: || Box::new(Runtime::new(LabBehavior::default(), LabModel::for_panel(RUNTIME_PANEL))),
    }
}
