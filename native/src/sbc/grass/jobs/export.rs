use std::path::PathBuf;

use log::{error, info};

use crate::sbc::command_system::context::Context;
use crate::sbc::grass::ops::export;
use crate::sbc::io::io_api::{IoJob, IoOutcome};
use crate::sbc::io::write::save_png;
use crate::sbc::sbc::SBC;

/// Reads the live grass map and queues a PNG export to `path`.
pub(crate) fn submit(ctx: &mut Context, path: PathBuf) {
    let Some(image) = export::export(ctx.interface) else {
        return;
    };
    ctx.submit_io(Box::new(GrassPngSaveJob { path, image }));
}

struct GrassPngSaveJob {
    path: PathBuf,
    image: image::RgbImage,
}

impl IoJob for GrassPngSaveJob {
    fn run(self: Box<Self>) -> Box<dyn IoOutcome> {
        Box::new(match save_png(&self.path, &self.image) {
            Ok(()) => GrassPngSaveOutcome::Saved(self.path),
            Err(reason) => GrassPngSaveOutcome::Failed(reason),
        })
    }
}

enum GrassPngSaveOutcome {
    Saved(PathBuf),
    Failed(String),
}

impl IoOutcome for GrassPngSaveOutcome {
    fn apply(self: Box<Self>, _sbc: &mut SBC) {
        match *self {
            GrassPngSaveOutcome::Saved(path) => info!("grass png saved: {}", path.display()),
            GrassPngSaveOutcome::Failed(reason) => error!("grass png save failed: {reason}"),
        }
    }
}
