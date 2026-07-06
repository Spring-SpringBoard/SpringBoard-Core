use serde::Deserialize;

use crate::sbc::command_system::command::Command;
use crate::sbc::command_system::context::Context;
use crate::sbc::command_system::io_completion;
use crate::sbc::command_system::registry::register_command;
use crate::sbc::compile::jobs::CompileMapJob;
use crate::sbc::compile::ops::compiler_path;
use crate::sbc::compile::CompileMapOpts;
use crate::sbc::lua_bridge;

#[derive(Deserialize, Debug)]
pub struct CompileMapCommand {
    #[serde(flatten)]
    opts: CompileMapOpts,
}

impl Command for CompileMapCommand {
    fn execute(&mut self, ctx: &mut Context) {
        lua_bridge::widget_command(
            ctx.interface,
            serde_json::json!({ "className": "CompileMapStarted" }),
        );
        match compiler_path(ctx) {
            Ok(compiler_path) => ctx.submit_io(Box::new(CompileMapJob {
                opts: self.opts.clone(),
                compiler_path,
            })),
            Err(reason) => log::error!("CompileMapCommand: {reason}"),
        }
        io_completion::submit_native_command_completed(ctx);
    }

    fn undoable(&self) -> bool {
        false
    }
}

register_command!(CompileMapCommand, "CompileMapCommand");
