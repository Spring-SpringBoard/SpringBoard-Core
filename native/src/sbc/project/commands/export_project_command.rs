use std::path::PathBuf;

use serde::Deserialize;

use crate::sbc::command_system::command::Command;
use crate::sbc::command_system::context::Context;
use crate::sbc::command_system::io_completion;
use crate::sbc::command_system::registry::register_command;
use crate::sbc::project::ops::archive;

#[derive(Deserialize, Debug)]
pub struct ExportProjectCommand {
    #[serde(rename = "archiveDir")]
    archive_dir: String,
    path: String,
}

impl Command for ExportProjectCommand {
    fn execute(&mut self, ctx: &mut Context) {
        let archive_dir = PathBuf::from(&self.archive_dir);
        let path = archive_path(&self.path);
        match archive::export(&archive_dir, &path) {
            Ok(()) => log::info!("project archive exported: {}", path.display()),
            Err(reason) => log::error!("project archive export failed: {reason}"),
        }
        io_completion::submit_native_command_completed(ctx);
    }

    fn undoable(&self) -> bool {
        false
    }
}

fn archive_path(path: &str) -> PathBuf {
    let mut out = PathBuf::from(path);
    if out.extension().and_then(|ext| ext.to_str()) != Some("sdz") {
        out.set_extension("sdz");
    }
    out
}

register_command!(ExportProjectCommand, "ExportProjectCommand");
