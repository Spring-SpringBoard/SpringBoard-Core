use std::path::Path;

use serde::{Deserialize, Deserializer};
use serde_json::{Map, Value};

use super::save_project_info_command::SCRIPT_FILE;
use crate::sbc::command_system::command::Command;
use crate::sbc::command_system::context::Context;
use crate::sbc::command_system::registry::register_command;
use crate::sbc::project::ops::{project_info, reload};
use crate::sbc::project::paths::ProjectPaths;
use crate::sbc::project::ProjectData;
use crate::sbc::teams::TeamManager;

#[derive(Deserialize, Debug)]
pub struct ReloadIntoProjectCommand {
    path: String,
    #[serde(default, rename = "modOptions", deserialize_with = "lua_map")]
    mod_options: Map<String, Value>,
    #[serde(rename = "gameName")]
    game_name: String,
    #[serde(rename = "gameVersion")]
    game_version: String,
    /// A freshly created project whose `script.txt` write is still in flight on
    /// the IO worker. When set, the reload builds the start script from this in
    /// memory instead of reading the not-yet-written file. Loading an existing
    /// project leaves it `None` and reads the on-disk script.
    #[serde(skip)]
    project: Option<ProjectData>,
}

/// Accept a JSON object as a map; treat anything else as empty. Lua serializes
/// an empty table as `[]`, not `{}`, so a map field that happens to be empty
/// arrives as a sequence.
fn lua_map<'de, D: Deserializer<'de>>(de: D) -> Result<Map<String, Value>, D::Error> {
    match Value::deserialize(de)? {
        Value::Object(map) => Ok(map),
        _ => Ok(Map::new()),
    }
}

impl ReloadIntoProjectCommand {
    /// Reload into an existing on-disk project (its `script.txt` is present).
    pub(crate) fn new(path: String, game_name: String, game_version: String) -> Self {
        Self {
            path,
            mod_options: Map::new(),
            game_name,
            game_version,
            project: None,
        }
    }

    /// Reload into a just-created project, building the start script from `project`
    /// rather than the `script.txt` the save is still writing asynchronously.
    pub(crate) fn for_new_project(
        path: String,
        game_name: String,
        game_version: String,
        project: ProjectData,
    ) -> Self {
        Self {
            path,
            mod_options: Map::new(),
            game_name,
            game_version,
            project: Some(project),
        }
    }
}

impl Command for ReloadIntoProjectCommand {
    fn execute(&mut self, ctx: &mut Context) {
        if let Err(reason) = self.run(ctx) {
            log::error!("reload into project failed: {reason}");
        }
    }

    fn undoable(&self) -> bool {
        false
    }
}

impl ReloadIntoProjectCommand {
    fn run(&self, ctx: &mut Context) -> Result<(), String> {
        // A new project's script.txt is still being written by the IO worker, so
        // build it from the project in memory; an existing project reads disk.
        let saved = match &self.project {
            Some(project) => {
                project_info::start_script(project, &ctx.model::<TeamManager>().all_teams())
            }
            None => {
                let path = ProjectPaths::new(Path::new(&self.path)).file(SCRIPT_FILE);
                std::fs::read_to_string(&path)
                    .map_err(|err| format!("read {}: {err}", path.display()))?
            }
        };
        let script = reload::start_script(
            &saved,
            &self.mod_options,
            &self.game_name,
            &self.game_version,
        )?;
        log::info!("reloading with project start script");
        ctx.interface
            .system_control()
            .reload(&script)
            .map_err(|err| format!("Spring.Reload: {err:?}"))?;
        Ok(())
    }
}

register_command!(ReloadIntoProjectCommand, "ReloadIntoProjectCommand");
