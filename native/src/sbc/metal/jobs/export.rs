use std::path::PathBuf;

use log::{error, info};

use crate::sbc::command_system::context::Context;
use crate::sbc::io::io_api::{IoJob, IoOutcome};
use crate::sbc::io::write::save_png;
use crate::sbc::metal::ops::export;
use crate::sbc::sbc::SBC;

/// Reads the live metal map and queues a PNG export to `path`.
pub(crate) fn submit(ctx: &mut Context, path: PathBuf) {
    let Some(image) = export::export(ctx.interface) else {
        return;
    };
    ctx.submit_io(Box::new(MetalPngSaveJob { path, image }));
}

struct MetalPngSaveJob {
    path: PathBuf,
    image: image::RgbImage,
}

impl IoJob for MetalPngSaveJob {
    fn run(self: Box<Self>) -> Box<dyn IoOutcome> {
        Box::new(match save_png(&self.path, &self.image) {
            Ok(()) => MetalPngSaveOutcome::Saved(self.path),
            Err(reason) => MetalPngSaveOutcome::Failed(reason),
        })
    }
}

enum MetalPngSaveOutcome {
    Saved(PathBuf),
    Failed(String),
}

impl IoOutcome for MetalPngSaveOutcome {
    fn apply(self: Box<Self>, _sbc: &mut SBC) {
        match *self {
            MetalPngSaveOutcome::Saved(path) => info!("metal png saved: {}", path.display()),
            MetalPngSaveOutcome::Failed(reason) => error!("metal png save failed: {reason}"),
        }
    }
}
