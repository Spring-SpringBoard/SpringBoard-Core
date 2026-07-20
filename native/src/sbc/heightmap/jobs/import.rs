use std::path::PathBuf;

use log::error;

use crate::sbc::command_system::context::Context;
use crate::sbc::heightmap::ops::{import, read, write, Heightmap};
use crate::sbc::io::io_api::{IoJob, IoOutcome};
use crate::sbc::notifications::NotificationManager;
use crate::sbc::sbc::SBC;

/// Queues importing a grayscale PNG at `path` into the live heightmap, mapping
/// luminance onto `[min, max]`.
pub(crate) fn submit(ctx: &mut Context, path: PathBuf, min: f32, max: f32) {
    let Some((width, height)) = read::dims(ctx.interface) else {
        error!("import heightmap: could not read heightmap size");
        return;
    };
    ctx.model::<NotificationManager>()
        .progress("import", 0.2, "Importing heightmap...");
    ctx.submit_io(Box::new(ImportHeightmapJob {
        path,
        width,
        height,
        min,
        max,
    }));
}

struct ImportHeightmapJob {
    path: PathBuf,
    width: usize,
    height: usize,
    min: f32,
    max: f32,
}

impl IoJob for ImportHeightmapJob {
    fn run(self: Box<Self>) -> Box<dyn IoOutcome> {
        Box::new(
            match import::import(&self.path, self.width, self.height, self.min, self.max) {
                Ok(map) => ImportHeightmapOutcome::Loaded(map),
                Err(reason) => ImportHeightmapOutcome::Failed(reason),
            },
        )
    }
}

enum ImportHeightmapOutcome {
    Loaded(Heightmap),
    Failed(String),
}

impl IoOutcome for ImportHeightmapOutcome {
    fn apply(self: Box<Self>, sbc: &mut SBC) {
        match *self {
            ImportHeightmapOutcome::Loaded(map) => {
                write::write(sbc.interface(), &map);
                sbc.model::<NotificationManager>()
                    .progress("import", 1.0, "Heightmap imported");
            }
            ImportHeightmapOutcome::Failed(reason) => {
                error!("heightmap import failed: {reason}");
                sbc.model::<NotificationManager>()
                    .warn("import", &format!("Heightmap import failed: {reason}"));
            }
        }
    }
}
