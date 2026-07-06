use std::path::PathBuf;

use log::{error, info};

use crate::sbc::io::io_api::{IoJob, IoOutcome};
use crate::sbc::project::ops::fs::write_bytes;
use crate::sbc::sbc::SBC;

pub(crate) struct WriteTextJob {
    pub path: PathBuf,
    pub text: String,
    pub what: &'static str,
}

impl IoJob for WriteTextJob {
    fn run(self: Box<Self>) -> Box<dyn IoOutcome> {
        Box::new(match write_bytes(&self.path, self.text.as_bytes()) {
            Ok(()) => WriteTextOutcome::Done {
                what: self.what,
                path: self.path,
            },
            Err(reason) => WriteTextOutcome::Failed {
                what: self.what,
                reason,
            },
        })
    }
}

enum WriteTextOutcome {
    Done { what: &'static str, path: PathBuf },
    Failed { what: &'static str, reason: String },
}

impl IoOutcome for WriteTextOutcome {
    fn apply(self: Box<Self>, _sbc: &mut SBC) {
        match *self {
            WriteTextOutcome::Done { what, path } => {
                info!("{what}: {}", path.display());
            }
            WriteTextOutcome::Failed { what, reason } => {
                error!("{what} failed: {reason}");
            }
        }
    }
}
