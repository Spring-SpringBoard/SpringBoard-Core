use std::path::PathBuf;

use serde::Deserialize;

use crate::sbc::command_system::command::Command;
use crate::sbc::command_system::context::Context;
use crate::sbc::command_system::registry::register_command;
use crate::sbc::project::io_registries::load;

#[derive(Deserialize, Debug)]
pub struct LoadProjectCommand {
    path: String,
}

impl Command for LoadProjectCommand {
    fn execute(&mut self, ctx: &mut Context) {
        load::load_project(ctx, &PathBuf::from(&self.path));
    }

    fn undoable(&self) -> bool {
        false
    }
}

register_command!(LoadProjectCommand, "LoadProjectCommand");
