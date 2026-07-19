mod behavior;
mod layout;
mod model;

use crate::sbc::panels::registry::{EditorSpec, Tab};
use crate::sbc::panels::runtime::Runtime;

use behavior::SettingsBehavior;
use model::SettingsModel;

// Mirrors TerrainSettingsEditor:Register in scen_edit/view/map/terrain_settings_editor.lua.
inventory::submit! {
    EditorSpec {
        name: "terrainSettingsEditor",
        tab: Tab::Map,
        order: 99,
        caption: "Settings",
        tooltip: "Map settings",
        image: "LuaUI/images/scenedit/globe.png",
        make: || Box::new(Runtime::new(SettingsBehavior, SettingsModel::new())),
    }
}
