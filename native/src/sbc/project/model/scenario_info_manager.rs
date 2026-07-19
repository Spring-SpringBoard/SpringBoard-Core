use std::any::Any;

use serde::{Deserialize, Serialize};
use spring_native::prelude::NativeInterfaceRef;

use crate::sbc::command_system::model::{Model, ModelFactory};
use crate::sbc::lua_bridge;

inventory::submit! { ModelFactory { make: |iface| Box::new(ScenarioInfoManager::new(iface)) } }

/// Project-level scenario metadata (name / description / version / author).
/// Mirrors `scen_edit/model/scenario_info.lua`. Pure project state; on change it
/// notifies the widget's mirror so the UI updates.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ScenarioInfo {
    pub name: String,
    pub description: String,
    pub version: String,
    pub author: String,
}

impl Default for ScenarioInfo {
    fn default() -> Self {
        ScenarioInfo {
            name: "Scenario".to_string(),
            description: String::new(),
            version: "1".to_string(),
            author: String::new(),
        }
    }
}

/// Partial-update payload: any field omitted leaves the current value untouched
/// (mirrors Lua's `data.x or self.x` merge in `ScenarioInfo:Set`).
#[derive(Debug, Clone, Default, Deserialize, Serialize)]
pub struct ScenarioInfoPatch {
    pub name: Option<String>,
    pub description: Option<String>,
    pub version: Option<String>,
    pub author: Option<String>,
}

pub struct ScenarioInfoManager {
    interface: NativeInterfaceRef,
    info: ScenarioInfo,
}

impl Model for ScenarioInfoManager {
    fn as_any_mut(&mut self) -> &mut dyn Any {
        self
    }
}

impl ScenarioInfoManager {
    pub fn new(interface: NativeInterfaceRef) -> Self {
        let player_name = interface
            .teams()
            .get_player_info_owned(0, false)
            .ok()
            .map(|info| info.name)
            .filter(|name| !name.is_empty())
            .unwrap_or_else(|| "Player".to_string());
        ScenarioInfoManager {
            interface,
            info: ScenarioInfo {
                name: format!("{player_name}'s Scenario"),
                author: player_name,
                ..ScenarioInfo::default()
            },
        }
    }

    /// Merge a partial patch over the current info (each absent field keeps its
    /// current value).
    pub fn set(&mut self, patch: &ScenarioInfoPatch) {
        if let Some(name) = &patch.name {
            self.info.name = name.clone();
        }
        if let Some(description) = &patch.description {
            self.info.description = description.clone();
        }
        if let Some(version) = &patch.version {
            self.info.version = version.clone();
        }
        if let Some(author) = &patch.author {
            self.info.author = author.clone();
        }
        self.notify();
    }

    /// Replace the whole info (used by undo to restore a prior full snapshot).
    pub fn restore(&mut self, info: ScenarioInfo) {
        self.info = info;
        self.notify();
    }

    pub fn serialize(&self) -> ScenarioInfo {
        self.info.clone()
    }

    fn notify(&self) {
        lua_bridge::widget_command(
            &self.interface,
            serde_json::json!({
                "className": "WidgetSetScenarioInfoCommand",
                "data": self.info,
            }),
        );
    }
}
