use std::path::PathBuf;

use log::error;

use crate::sbc::command_system::context::Context;
use crate::sbc::heightmap::ops::{load, read, write, Heightmap};
use crate::sbc::io::io_api::{IoJob, IoOutcome};
use crate::sbc::sbc::SBC;

/// Queues loading a `.data` heightmap from `path` into the live map.
pub(crate) fn submit(ctx: &mut Context, path: PathBuf) {
    let Some((width, height)) = read::dims(ctx.interface) else {
        error!("load heightmap: could not read heightmap size");
        return;
    };
    ctx.submit_io(Box::new(LoadHeightmapJob {
        path,
        width,
        height,
    }));
}

struct LoadHeightmapJob {
    path: PathBuf,
    width: usize,
    height: usize,
}

impl IoJob for LoadHeightmapJob {
    fn run(self: Box<Self>) -> Box<dyn IoOutcome> {
        let bytes = match std::fs::read(&self.path) {
            Ok(bytes) => bytes,
            Err(err) => {
                return Box::new(LoadHeightmapOutcome::Failed(format!(
                    "read {}: {err}",
                    self.path.display()
                )));
            }
        };
        Box::new(match load::load(&bytes, self.width, self.height) {
            Ok(map) => LoadHeightmapOutcome::Loaded(map),
            Err(reason) => {
                LoadHeightmapOutcome::Failed(format!("{}: {reason}", self.path.display()))
            }
        })
    }
}

enum LoadHeightmapOutcome {
    Loaded(Heightmap),
    Failed(String),
}

impl IoOutcome for LoadHeightmapOutcome {
    fn apply(self: Box<Self>, sbc: &mut SBC) {
        match *self {
            LoadHeightmapOutcome::Loaded(map) => write::write(sbc.interface(), &map),
            LoadHeightmapOutcome::Failed(reason) => error!("heightmap load failed: {reason}"),
        }
    }
}
