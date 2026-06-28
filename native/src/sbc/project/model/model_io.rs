use std::path::PathBuf;

use log::{error, info};
use serde_json::Value;

use super::model_codec::{load_model, serialize_model};
use crate::sbc::io::io_api::{IoJob, IoOutcome};
use crate::sbc::message_handler::MessageHandler;
use crate::sbc::sbc::SBC;

inventory::submit! { MessageHandler { tag: "save_model", handler: save_model_file } }
inventory::submit! { MessageHandler { tag: "load_model", handler: load_model_file } }

pub fn save_model_file(sbc: &mut SBC, data: serde_json::Value) {
    let Some(path) = data.get("path").and_then(|p| p.as_str()) else {
        error!("save_model: missing 'path'");
        return;
    };
    let json = match serde_json::to_string_pretty(&serialize_model(sbc)) {
        Ok(s) => s,
        Err(err) => {
            error!("save_model: serialize failed: {err}");
            return;
        }
    };
    sbc.submit_io_job(Box::new(ModelIoJob::Save {
        path: PathBuf::from(path),
        json,
    }));
}

pub fn load_model_file(sbc: &mut SBC, data: serde_json::Value) {
    let Some(path) = data.get("path").and_then(|p| p.as_str()) else {
        error!("load_model: missing 'path'");
        return;
    };
    sbc.submit_io_job(Box::new(ModelIoJob::Load {
        path: PathBuf::from(path),
    }));
}

pub enum ModelIoJob {
    Save { path: PathBuf, json: String },
    Load { path: PathBuf },
}

impl IoJob for ModelIoJob {
    fn run(self: Box<Self>) -> Box<dyn IoOutcome> {
        let outcome = match *self {
            ModelIoJob::Save { path, json } => match std::fs::write(&path, json) {
                Ok(()) => ModelIoOutcome::Saved { path },
                Err(err) => ModelIoOutcome::Failed {
                    op: "save model",
                    reason: format!("write {}: {err}", path.display()),
                },
            },
            ModelIoJob::Load { path } => match std::fs::read_to_string(&path) {
                Ok(text) => match serde_json::from_str::<Value>(&text) {
                    Ok(mission) => ModelIoOutcome::Loaded {
                        mission: Box::new(mission),
                    },
                    Err(err) => ModelIoOutcome::Failed {
                        op: "load model",
                        reason: format!("parse {}: {err}", path.display()),
                    },
                },
                Err(err) => ModelIoOutcome::Failed {
                    op: "load model",
                    reason: format!("read {}: {err}", path.display()),
                },
            },
        };
        Box::new(outcome)
    }
}

/// Outcome of a model IO job, applied on the engine thread.
pub enum ModelIoOutcome {
    Saved { path: PathBuf },
    Loaded { mission: Box<Value> },
    Failed { op: &'static str, reason: String },
}

impl IoOutcome for ModelIoOutcome {
    fn apply(self: Box<Self>, sbc: &mut SBC) {
        match *self {
            ModelIoOutcome::Saved { path } => {
                info!("model saved: {}", path.display());
            }
            ModelIoOutcome::Loaded { mission } => {
                load_model(sbc, &mission);
                info!("model loaded");
            }
            ModelIoOutcome::Failed { op, reason } => {
                error!("{op} failed: {reason}");
            }
        }
    }
}
