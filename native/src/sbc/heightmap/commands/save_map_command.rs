use std::path::PathBuf;

use serde::Deserialize;

use crate::sbc::command_system::command::Command;
use crate::sbc::command_system::context::Context;
use crate::sbc::command_system::registry::register_command;
use crate::sbc::heightmap::jobs;

#[derive(Deserialize, Debug)]
pub struct SaveMapCommand {
    path: String,
}

impl Command for SaveMapCommand {
    fn execute(&mut self, ctx: &mut Context) {
        jobs::save::submit(ctx, PathBuf::from(&self.path));
    }

    fn undoable(&self) -> bool {
        false
    }
}

register_command!(SaveMapCommand, "SaveMapCommand");
