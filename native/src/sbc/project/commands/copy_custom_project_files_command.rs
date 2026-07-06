use std::path::Path;

use serde::Deserialize;

use crate::sbc::command_system::command::Command;
use crate::sbc::command_system::context::Context;
use crate::sbc::command_system::io_completion;
use crate::sbc::command_system::registry::register_command;
use crate::sbc::project::ops::custom_files;

#[derive(Deserialize, Debug)]
pub struct CopyCustomProjectFilesCommand {
    src: String,
    dest: String,
}

impl Command for CopyCustomProjectFilesCommand {
    fn execute(&mut self, ctx: &mut Context) {
        match custom_files::copy(Path::new(&self.src), Path::new(&self.dest)) {
            Ok(()) => log::info!("custom project files copied"),
            Err(reason) => log::error!("custom project file copy failed: {reason}"),
        }
        io_completion::submit_native_command_completed(ctx);
    }

    fn undoable(&self) -> bool {
        false
    }
}

register_command!(
    CopyCustomProjectFilesCommand,
    "CopyCustomProjectFilesCommand"
);
