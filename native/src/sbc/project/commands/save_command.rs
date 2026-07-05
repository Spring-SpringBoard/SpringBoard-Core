use std::path::PathBuf;

use serde::Deserialize;

use crate::sbc::command_system::command::Command;
use crate::sbc::command_system::context::Context;
use crate::sbc::command_system::registry::register_command;
use crate::sbc::project::io_registries::save;

#[derive(Deserialize, Debug)]
pub struct SaveCommand {
    path: String,
    #[serde(default, rename = "isNewProject")]
    is_new_project: bool,
}

impl Command for SaveCommand {
    fn execute(&mut self, ctx: &mut Context) {
        save::save_project(ctx, &PathBuf::from(&self.path), self.is_new_project);
    }

    fn undoable(&self) -> bool {
        false
    }
}

register_command!(SaveCommand, "SaveCommand");
