use std::path::PathBuf;

use log::{error, info};

use crate::sbc::command_system::context::Context;
use crate::sbc::grass::ops::read;
use crate::sbc::io::io_api::{IoJob, IoOutcome};
use crate::sbc::io::write::write_bytes;
use crate::sbc::sbc::SBC;

/// Reads the live grass map and queues writing it to `path`.
pub(crate) fn submit(ctx: &mut Context, path: PathBuf) {
    let Some(bytes) = read::read(ctx.interface) else {
        error!("save grass map: could not read map size");
        return;
    };
    ctx.submit_io(Box::new(GrassSaveJob { path, bytes }));
}

struct GrassSaveJob {
    path: PathBuf,
    bytes: Vec<u8>,
}

impl IoJob for GrassSaveJob {
    fn run(self: Box<Self>) -> Box<dyn IoOutcome> {
        Box::new(match write_bytes(&self.path, &self.bytes) {
            Ok(()) => GrassSaveOutcome::Saved(self.path),
            Err(reason) => GrassSaveOutcome::Failed(reason),
        })
    }
}

enum GrassSaveOutcome {
    Saved(PathBuf),
    Failed(String),
}

impl IoOutcome for GrassSaveOutcome {
    fn apply(self: Box<Self>, _sbc: &mut SBC) {
        match *self {
            GrassSaveOutcome::Saved(path) => info!("grass map saved: {}", path.display()),
            GrassSaveOutcome::Failed(reason) => error!("grass map save failed: {reason}"),
        }
    }
}
