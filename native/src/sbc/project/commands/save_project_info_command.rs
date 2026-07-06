use std::path::PathBuf;

use serde::Deserialize;

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

impl Command for SaveProjectInfoCommand {
    fn execute(&mut self, ctx: &mut Context) {
        let mut project = self
            .project
            .clone()
            .unwrap_or_else(|| ctx.model::<ProjectManager>().serialize().clone());
        project.name = Some(self.name.clone());
        project.path = Some(self.path.clone());
        if project.mutators.is_empty() {
            project.mutators = vec![format!("{} 1.0", self.name)];
        }
        ctx.model::<ProjectManager>().restore(project.clone());

        let scenario_info = ctx.model::<ScenarioInfoManager>().serialize();
        let teams = ctx.model::<TeamManager>().all_teams();
        let root = PathBuf::from(&self.path);
        let paths = ProjectPaths::new(&root);

        ctx.submit_io(Box::new(WriteTextJob {
            path: root.join("mapinfo.lua"),
            text: project_info::mapinfo(&self.name, &teams),
            what: "save project mapinfo",
        }));
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

register_command!(SaveProjectInfoCommand, "SaveProjectInfoCommand");
