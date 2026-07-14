use std::path::PathBuf;

use serde::Deserialize;

use crate::sbc::command_system::command::Command;
use crate::sbc::command_system::context::Context;
use crate::sbc::command_system::io_completion;
use crate::sbc::command_system::registry::register_command;
use crate::sbc::project::jobs::WriteTextJob;
use crate::sbc::project::ops::map_info;

#[derive(Deserialize, Debug)]
pub struct ExportMapInfoCommand {
    path: String,
}

impl ExportMapInfoCommand {
    pub(crate) fn new(path: String) -> Self {
        Self { path }
    }
}

impl Command for ExportMapInfoCommand {
    fn execute(&mut self, ctx: &mut Context) {
        let text = map_info::export_text(ctx);
        ctx.submit_io(Box::new(WriteTextJob {
            path: lua_path(&self.path),
            text,
            what: "export mapinfo",
        }));
        io_completion::submit_native_command_completed(ctx);
    }

    fn undoable(&self) -> bool {
        false
    }
}

fn lua_path(path: &str) -> PathBuf {
    let mut out = PathBuf::from(path);
    if out.extension().and_then(|ext| ext.to_str()) != Some("lua") {
        out.set_extension("lua");
    }
    out
}

register_command!(ExportMapInfoCommand, "ExportMapInfoCommand");
