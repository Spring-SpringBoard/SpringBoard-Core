use std::path::PathBuf;

use log::error;

use crate::sbc::command_system::context::Context;
use crate::sbc::grass::ops::write;
use crate::sbc::io::io_api::{IoJob, IoOutcome};
use crate::sbc::sbc::SBC;

/// Queues loading a grass map from `path` into the live map.
pub(crate) fn submit(ctx: &mut Context, path: PathBuf) {
    ctx.submit_io(Box::new(GrassLoadJob { path }));
}

struct GrassLoadJob {
    path: PathBuf,
}

impl IoJob for GrassLoadJob {
    fn run(self: Box<Self>) -> Box<dyn IoOutcome> {
        Box::new(match std::fs::read(&self.path) {
            Ok(bytes) => GrassLoadOutcome::Loaded(bytes),
            Err(err) => GrassLoadOutcome::Failed(format!("read {}: {err}", self.path.display())),
        })
    }
}

enum GrassLoadOutcome {
    Loaded(Vec<u8>),
    Failed(String),
}

impl IoOutcome for GrassLoadOutcome {
    fn apply(self: Box<Self>, sbc: &mut SBC) {
        match *self {
            GrassLoadOutcome::Loaded(bytes) => write::write(sbc, &bytes),
            GrassLoadOutcome::Failed(reason) => error!("grass map load failed: {reason}"),
        }
    }
}
