use std::path::PathBuf;

use log::error;

use crate::sbc::command_system::context::Context;
use crate::sbc::io::io_api::{IoJob, IoOutcome};
use crate::sbc::metal::ops::write;
use crate::sbc::sbc::SBC;

/// Queues loading a metal map from `path` into the live map.
pub(crate) fn submit(ctx: &mut Context, path: PathBuf) {
    ctx.submit_io(Box::new(MetalLoadJob { path }));
}

struct MetalLoadJob {
    path: PathBuf,
}

impl IoJob for MetalLoadJob {
    fn run(self: Box<Self>) -> Box<dyn IoOutcome> {
        Box::new(match std::fs::read(&self.path) {
            Ok(bytes) => MetalLoadOutcome::Loaded(bytes),
            Err(err) => MetalLoadOutcome::Failed(format!("read {}: {err}", self.path.display())),
        })
    }
}

enum MetalLoadOutcome {
    Loaded(Vec<u8>),
    Failed(String),
}

impl IoOutcome for MetalLoadOutcome {
    fn apply(self: Box<Self>, sbc: &mut SBC) {
        match *self {
            MetalLoadOutcome::Loaded(bytes) => write::write(sbc, &bytes),
            MetalLoadOutcome::Failed(reason) => error!("metal map load failed: {reason}"),
        }
    }
}
