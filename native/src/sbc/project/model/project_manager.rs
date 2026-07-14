use std::any::Any;

use serde::{Deserialize, Serialize};
use spring_native::prelude::NativeInterfaceRef;

use crate::sbc::command_system::model::{Model, ModelFactory};
use crate::sbc::lua_bridge;

inventory::submit! { ModelFactory { make: |iface| Box::new(ProjectManager::new(iface)) } }

/// Project-level metadata (name, path, target game, map, mutators) — the pure-state
/// half of `project.lua`. File/launcher concerns (create structure, env init,
/// load-from-file, window title) stay Lua-side.
#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct ProjectData {
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub name: Option<String>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub path: Option<String>,
    #[serde(default, rename = "mapName", skip_serializing_if = "Option::is_none")]
    pub map_name: Option<String>,
    /// Target game `{ name, version }`, preserved verbatim.
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub game: Option<serde_json::Value>,
    #[serde(
        default,
        rename = "randomMapOptions",
        skip_serializing_if = "Option::is_none"
    )]
    pub random_map_options: Option<serde_json::Value>,
    #[serde(default)]
    pub mutators: Vec<String>,
}

pub struct ProjectManager {
    interface: NativeInterfaceRef,
    project: ProjectData,
}

impl Model for ProjectManager {
    fn as_any_mut(&mut self) -> &mut dyn Any {
        self
    }
}

impl ProjectManager {
    pub fn new(interface: NativeInterfaceRef) -> Self {
        ProjectManager {
            interface,
            project: ProjectData::default(),
        }
    }

    /// Set name + path, rewriting mutators prefixed with the old name to `<newName> 1.0`.
    /// Rust owns the mutator rewrite; the Lua `SB.project` mirror is refreshed via notify.
    pub fn set_name_path(&mut self, name: &str, path: &str) {
        if let Some(old_name) = &self.project.name {
            let prefix = old_name.clone();
            for mutator in &mut self.project.mutators {
                if mutator.starts_with(&prefix) {
                    *mutator = format!("{name} 1.0");
                }
            }
        }
        self.project.name = Some(name.to_string());
        self.project.path = Some(path.to_string());
        self.notify_project();
    }

    /// The project data, for the project-info save (still to land).
    #[allow(dead_code)]
    pub fn serialize(&self) -> &ProjectData {
        &self.project
    }

    pub fn restore(&mut self, project: ProjectData) {
        self.project = project;
    }

    #[allow(dead_code)]
    pub fn name(&self) -> Option<&str> {
        self.project.name.as_deref()
    }

    #[allow(dead_code)]
    pub fn path(&self) -> Option<&str> {
        self.project.path.as_deref()
    }

    /// Push name/path/mutators to the Lua `SB.project` in both states (the synced
    /// gadget model and the unsynced widget UI), mirroring what the old Lua
    /// `SetProjectNamePathCommand` set directly in each state.
    fn notify_project(&self) {
        let data = serde_json::json!({
            "className": "WidgetSetProjectCommand",
            "name": self.project.name,
            "path": self.project.path,
            "mutators": self.project.mutators,
        });
        lua_bridge::widget_command(&self.interface, data.clone());
        lua_bridge::rules_command(&self.interface, data);
    }
}
