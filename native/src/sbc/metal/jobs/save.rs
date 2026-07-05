use std::path::PathBuf;

use log::{error, info};

use crate::sbc::command_system::context::Context;
use crate::sbc::io::io_api::{IoJob, IoOutcome};
use crate::sbc::io::write::write_bytes;
use crate::sbc::metal::ops::read;
use crate::sbc::sbc::SBC;

/// Reads the live metal map and queues writing it to `path`.
pub(crate) fn submit(ctx: &mut Context, path: PathBuf) {
    let Some(bytes) = read::read(ctx.interface) else {
        error!("save metal map: could not read map size");
        return;
    };
    ctx.submit_io(Box::new(MetalSaveJob { path, bytes }));
}

struct MetalSaveJob {
    path: PathBuf,
    bytes: Vec<u8>,
}

impl IoJob for MetalSaveJob {
    fn run(self: Box<Self>) -> Box<dyn IoOutcome> {
        Box::new(match write_bytes(&self.path, &self.bytes) {
            Ok(()) => MetalSaveOutcome::Saved(self.path),
            Err(reason) => MetalSaveOutcome::Failed(reason),
        })
    }
}

enum MetalSaveOutcome {
    Saved(PathBuf),
    Failed(String),
}

impl IoOutcome for MetalSaveOutcome {
    fn apply(self: Box<Self>, _sbc: &mut SBC) {
        match *self {
            MetalSaveOutcome::Saved(path) => info!("metal map saved: {}", path.display()),
            MetalSaveOutcome::Failed(reason) => error!("metal map save failed: {reason}"),
        }
    }
}
