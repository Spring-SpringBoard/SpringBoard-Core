use std::path::PathBuf;

use log::{debug, error, info};

use crate::sbc::command_system::context::Context;
use crate::sbc::heightmap::ops::export::Png16;
use crate::sbc::heightmap::ops::{export, read};
use crate::sbc::io::io_api::{IoJob, IoOutcome};
use crate::sbc::io::write::save_png16;
use crate::sbc::sbc::SBC;

/// Reads the live heightmap and queues a 16-bit grayscale PNG export to `path`.
/// `heightmap_extremes` (`[min, max, ..]`) fixes the normalization range;
/// absent, the map's own extremes are used.
pub(crate) fn submit(ctx: &mut Context, path: PathBuf, heightmap_extremes: Option<Vec<f32>>) {
    let Some(map) = read::read(ctx.interface) else {
        error!("export heightmap: could not read heightmap size");
        return;
    };
    let (min, max) = match heightmap_extremes.as_deref() {
        Some(&[min, max, ..]) => (min, max),
        _ => export::extremes(&map.heights),
    };
    debug!(
        "export heightmap: {} ({}x{}) [{}, {}]",
        path.display(),
        map.width,
        map.height,
        min,
        max
    );
    ctx.submit_io(Box::new(ExportHeightmapJob {
        path,
        image: export::export(&map, min, max),
    }));
}

struct ExportHeightmapJob {
    path: PathBuf,
    image: Png16,
}

impl IoJob for ExportHeightmapJob {
    fn run(self: Box<Self>) -> Box<dyn IoOutcome> {
        Box::new(match save_png16(&self.path, &self.image) {
            Ok(()) => ExportHeightmapOutcome::Exported(self.path),
            Err(reason) => ExportHeightmapOutcome::Failed(reason),
        })
    }
}

enum ExportHeightmapOutcome {
    Exported(PathBuf),
    Failed(String),
}

impl IoOutcome for ExportHeightmapOutcome {
    fn apply(self: Box<Self>, _sbc: &mut SBC) {
        match *self {
            ExportHeightmapOutcome::Exported(path) => info!("export complete: {}", path.display()),
            ExportHeightmapOutcome::Failed(reason) => error!("heightmap export failed: {reason}"),
        }
    }
}
