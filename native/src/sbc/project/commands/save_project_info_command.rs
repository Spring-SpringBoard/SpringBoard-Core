use std::path::PathBuf;

use serde::Deserialize;
use spring_native::prelude::NativeInterfaceRef;

use crate::sbc::command_system::command::Command;
use crate::sbc::command_system::context::Context;
use crate::sbc::command_system::registry::register_command;
use crate::sbc::project::jobs::WriteTextJob;
use crate::sbc::project::ops::project_info;
use crate::sbc::project::paths::ProjectPaths;
use crate::sbc::project::{ProjectData, ProjectManager, ScenarioInfoManager};
use crate::sbc::teams::TeamManager;

/// Start-script file name; shared with [`super::reload_into_project_command`].
pub(super) const SCRIPT_FILE: &str = "script.txt";
const PROJECT_FILE: &str = "project.lua";

#[derive(Deserialize, Debug)]
pub struct SaveProjectInfoCommand {
    name: String,
    path: String,
    #[serde(default, rename = "isNewProject")]
    _is_new_project: bool,
    #[serde(default)]
    project: Option<ProjectData>,
}

impl SaveProjectInfoCommand {
    pub(crate) fn new(
        name: String,
        path: String,
        is_new_project: bool,
        project: Option<ProjectData>,
    ) -> Self {
        Self {
            name,
            path,
            _is_new_project: is_new_project,
            project,
        }
    }
}

impl Command for SaveProjectInfoCommand {
    fn execute(&mut self, ctx: &mut Context) {
        let mut project = self
            .project
            .clone()
            .unwrap_or_else(|| ctx.model::<ProjectManager>().serialize().clone());
        project.name = Some(self.name.clone());
        project.path = Some(self.path.clone());
        // A project saved from a booted or loaded editor carries no map or game:
        // a full reload resets ProjectManager to default, so the fields the New
        // Project dialog sets are gone. Capture the engine's current map and game
        // when they are missing, or the saved start script has no map and the
        // reload aborts with "No map selected in startscript".
        if project.map_name.is_none() {
            project.map_name = current_map_name(ctx.interface);
        }
        if project.game.is_none() {
            if let Ok(info) = ctx.interface.game().get_game_mod_info_owned() {
                project.game = Some(serde_json::json!({
                    "name": info.game_name,
                    "version": info.game_version,
                }));
            }
        }
        if project.mutators.is_empty() {
            project.mutators = vec![format!("{} 1.0", self.name)];
        }
        ctx.model::<ProjectManager>().restore(project.clone());

        let scenario_info = ctx.model::<ScenarioInfoManager>().serialize();
        let teams = ctx.model::<TeamManager>().all_teams();
        let root = PathBuf::from(&self.path);
        let paths = ProjectPaths::new(&root);

        ctx.submit_io(Box::new(WriteTextJob {
            path: paths.file(SCRIPT_FILE),
            text: project_info::start_script(&project, &teams),
            what: "save project start script",
        }));
        ctx.submit_io(Box::new(WriteTextJob {
            path: paths.file(PROJECT_FILE),
            text: project_info::project_lua(&project),
            what: "save project info",
        }));
        ctx.submit_io(Box::new(WriteTextJob {
            path: root.join("modinfo.lua"),
            text: project_info::modinfo(&scenario_info, &project),
            what: "save project modinfo",
        }));
    }

    fn undoable(&self) -> bool {
        false
    }
}

/// The name of the map the engine currently has loaded (Lua's `Game.mapName`).
fn current_map_name(interface: &NativeInterfaceRef) -> Option<String> {
    let name = interface.game().get_game_map_info_owned().ok()?.map_name;
    (!name.is_empty()).then_some(name)
}

register_command!(SaveProjectInfoCommand, "SaveProjectInfoCommand");
