use std::path::PathBuf;

use serde::Deserialize;

use crate::sbc::command_system::command::Command;
use crate::sbc::command_system::context::Context;
use crate::sbc::command_system::io_completion;
use crate::sbc::command_system::registry::register_command;
use crate::sbc::project::jobs::WriteTextJob;
use crate::sbc::project::ops::{lua_writer, model_codec};

#[derive(Deserialize, Debug)]
pub struct ExportS11NCommand {
    path: String,
}

impl Command for ExportS11NCommand {
    fn execute(&mut self, ctx: &mut Context) {
        let path = lua_path(&self.path);
        let model = model_codec::serialize_model_ctx(ctx);
        ctx.submit_io(Box::new(WriteTextJob {
            path,
            text: lua_writer::table_file(&model),
            what: "export s11n model",
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

register_command!(ExportS11NCommand, "ExportS11NCommand");
