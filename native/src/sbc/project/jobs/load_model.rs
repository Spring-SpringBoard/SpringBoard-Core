use std::path::PathBuf;

use log::{error, info};
use serde_json::Value;

use crate::sbc::command_system::context::Context;
use crate::sbc::io::io_api::{IoJob, IoOutcome};
use crate::sbc::project::io_registries::load::ProjectLoadRegistration;
use crate::sbc::project::ops::model_codec::load_model;
use super::save_model::MODEL_FILE;
use crate::sbc::project::paths::ProjectPaths;
use crate::sbc::sbc::SBC;

inventory::submit! {
    ProjectLoadRegistration { load: load_model_project }
}

fn load_model_project(ctx: &mut Context, paths: &ProjectPaths) {
    let path = paths.file(MODEL_FILE);
    if path.is_file() {
        ctx.submit_io(Box::new(LoadModelJob { path }));
    }
}

pub(crate) struct LoadModelJob {
    pub path: PathBuf,
}

impl IoJob for LoadModelJob {
    fn run(self: Box<Self>) -> Box<dyn IoOutcome> {
        Box::new(match std::fs::read_to_string(&self.path) {
            Ok(text) => match serde_json::from_str::<Value>(&text) {
                Ok(mission) => LoadModelOutcome::Loaded {
                    mission: Box::new(mission),
                },
                Err(err) => LoadModelOutcome::Failed {
                    reason: format!("parse {}: {err}", self.path.display()),
                },
            },
            Err(err) => LoadModelOutcome::Failed {
                reason: format!("read {}: {err}", self.path.display()),
            },
        })
    }
}

enum LoadModelOutcome {
    Loaded { mission: Box<Value> },
    Failed { reason: String },
}

impl IoOutcome for LoadModelOutcome {
    fn apply(self: Box<Self>, sbc: &mut SBC) {
        match *self {
            LoadModelOutcome::Loaded { mission } => {
                load_model(sbc, &mission);
                info!("model loaded");
            }
            LoadModelOutcome::Failed { reason } => error!("load model failed: {reason}"),
        }
    }
}
