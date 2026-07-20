use std::path::PathBuf;

use serde::Deserialize;

use crate::sbc::command_system::command::Command;
use crate::sbc::command_system::context::Context;
use crate::sbc::command_system::registry::register_command;
use crate::sbc::project::io_registries::load;
use crate::sbc::project::ProjectManager;

#[derive(Deserialize, Debug)]
pub struct LoadProjectCommand {
    path: String,
}

impl Command for LoadProjectCommand {
    fn execute(&mut self, ctx: &mut Context) {
        let path = PathBuf::from(&self.path);
        load::load_project(ctx, &path);
        // A reload or open resets ProjectManager to default, so restore the
        // project's identity here. Without it Save (Ctrl+S) treats the loaded
        // project as unsaved and reopens Save As, and Export has no project path.
        let name = path
            .file_stem()
            .and_then(|stem| stem.to_str())
            .unwrap_or_default()
            .to_string();
        ctx.model::<ProjectManager>()
            .set_name_path(&name, &self.path);
    }

    fn undoable(&self) -> bool {
        false
    }
}

register_command!(LoadProjectCommand, "LoadProjectCommand");
