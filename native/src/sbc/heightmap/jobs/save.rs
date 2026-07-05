use std::path::PathBuf;

use log::{error, info};

use crate::sbc::command_system::context::Context;
use crate::sbc::heightmap::ops::{read, save};
use crate::sbc::io::io_api::{IoJob, IoOutcome};
use crate::sbc::io::write::write_bytes;
use crate::sbc::sbc::SBC;

/// Reads the live heightmap and queues writing it to `path`.
pub(crate) fn submit(ctx: &mut Context, path: PathBuf) {
    let Some(map) = read::read(ctx.interface) else {
        error!("save heightmap: could not read heightmap size");
        return;
    };
    ctx.submit_io(Box::new(SaveHeightmapJob {
        path,
        bytes: save::save(&map.heights),
    }));
}

struct SaveHeightmapJob {
    path: PathBuf,
    bytes: Vec<u8>,
}

impl IoJob for SaveHeightmapJob {
    fn run(self: Box<Self>) -> Box<dyn IoOutcome> {
        Box::new(match write_bytes(&self.path, &self.bytes) {
            Ok(()) => SaveHeightmapOutcome::Saved(self.path),
            Err(reason) => SaveHeightmapOutcome::Failed(reason),
        })
    }
}

enum SaveHeightmapOutcome {
    Saved(PathBuf),
    Failed(String),
}

impl IoOutcome for SaveHeightmapOutcome {
    fn apply(self: Box<Self>, _sbc: &mut SBC) {
        match *self {
            SaveHeightmapOutcome::Saved(path) => info!("heightmap saved: {}", path.display()),
            SaveHeightmapOutcome::Failed(reason) => error!("heightmap save failed: {reason}"),
        }
    }
}
