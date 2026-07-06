use std::path::Path;

use serde::{Deserialize, Deserializer};
use serde_json::{Map, Value};

use super::save_project_info_command::SCRIPT_FILE;
use crate::sbc::command_system::command::Command;
use crate::sbc::command_system::context::Context;
use crate::sbc::command_system::registry::register_command;
use crate::sbc::project::ops::reload;
use crate::sbc::project::paths::ProjectPaths;

#[derive(Deserialize, Debug)]
pub struct ReloadIntoProjectCommand {
    path: String,
    #[serde(default, rename = "modOptions", deserialize_with = "lua_map")]
    mod_options: Map<String, Value>,
    #[serde(rename = "gameName")]
    game_name: String,
    #[serde(rename = "gameVersion")]
    game_version: String,
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
        let path = ProjectPaths::new(Path::new(&self.path)).file(SCRIPT_FILE);
        let saved = std::fs::read_to_string(&path)
            .map_err(|err| format!("read {}: {err}", path.display()))?;
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
