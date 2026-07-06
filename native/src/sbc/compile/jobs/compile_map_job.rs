use std::path::PathBuf;

use log::info;

use crate::sbc::compile::ops;
use crate::sbc::compile::CompileMapOpts;
use crate::sbc::io::io_api::{IoJob, IoOutcome};
use crate::sbc::lua_bridge;
use crate::sbc::sbc::SBC;

pub(crate) struct CompileMapJob {
    pub opts: CompileMapOpts,
    pub compiler_path: PathBuf,
}

impl IoJob for CompileMapJob {
    fn run(self: Box<Self>) -> Box<dyn IoOutcome> {
        Box::new(match ops::run(&self.opts, &self.compiler_path) {
            Ok(output_path) => CompileMapOutcome::Compiled { output_path },
            Err(reason) => CompileMapOutcome::Failed { reason },
        })
    }
}

enum CompileMapOutcome {
    Compiled { output_path: PathBuf },
    Failed { reason: String },
}

impl IoOutcome for CompileMapOutcome {
    fn apply(self: Box<Self>, sbc: &mut SBC) {
        match *self {
            CompileMapOutcome::Compiled { output_path } => {
                info!("map compiled: {}", output_path.display());
                lua_bridge::widget_command(
                    sbc.interface(),
                    serde_json::json!({ "className": "CompileMapFinished" }),
                );
            }
            CompileMapOutcome::Failed { reason } => {
                log::error!("map compile failed: {reason}");
                lua_bridge::widget_command(
                    sbc.interface(),
                    serde_json::json!({ "className": "CompileMapError", "msg": reason }),
                );
            }
        }
    }
}
