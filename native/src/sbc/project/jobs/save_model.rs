use std::path::PathBuf;

use log::{error, info};

use crate::sbc::command_system::context::Context;
use crate::sbc::io::io_api::{IoJob, IoOutcome};
use crate::sbc::project::io_registries::save::ProjectSaveRegistration;
use crate::sbc::project::ops::fs::write_bytes;
use crate::sbc::project::ops::model_codec::serialize_model_ctx;
use crate::sbc::project::paths::ProjectPaths;
use crate::sbc::sbc::SBC;

/// On-disk name of the serialized editor model; shared with [`super::load_model`].
pub(super) const MODEL_FILE: &str = "model.lua";

inventory::submit! {
    ProjectSaveRegistration { save: save_model }
}

fn save_model(ctx: &mut Context, paths: &ProjectPaths, _is_new_project: bool) {
    let json = match serde_json::to_string_pretty(&serialize_model_ctx(ctx)) {
        Ok(json) => json,
        Err(err) => {
            error!("save_model: serialize failed: {err}");
            return;
        }
    };
    ctx.submit_io(Box::new(SaveModelJob {
        path: paths.file(MODEL_FILE),
        json,
    }));
}

pub(crate) struct SaveModelJob {
    pub path: PathBuf,
    pub json: String,
}

impl IoJob for SaveModelJob {
    fn run(self: Box<Self>) -> Box<dyn IoOutcome> {
        Box::new(match write_bytes(&self.path, self.json.as_bytes()) {
            Ok(()) => SaveModelOutcome::Saved { path: self.path },
            Err(reason) => SaveModelOutcome::Failed { reason },
        })
    }
}

enum SaveModelOutcome {
    Saved { path: PathBuf },
    Failed { reason: String },
}

impl IoOutcome for SaveModelOutcome {
    fn apply(self: Box<Self>, _sbc: &mut SBC) {
        match *self {
            SaveModelOutcome::Saved { path } => info!("model saved: {}", path.display()),
            SaveModelOutcome::Failed { reason } => error!("save model failed: {reason}"),
        }
    }
}
