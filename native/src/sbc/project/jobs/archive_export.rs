use std::path::PathBuf;

use log::{error, info};

use crate::sbc::io::io_api::{IoJob, IoOutcome};
use crate::sbc::project::ops::spring_archive::{self, Spec};
use crate::sbc::sbc::SBC;

pub(crate) use spring_archive::ArchiveAsset;

pub(crate) struct ExportSpringArchiveJob {
    pub build_dir: PathBuf,
    pub archive_dir: PathBuf,
    pub maps_dir: PathBuf,
    pub project_path: PathBuf,
    pub project_name: String,
    pub output_path: PathBuf,
    pub compiler_path: PathBuf,
    pub map_info: String,
    pub s11n_model: String,
    pub assets: Vec<ArchiveAsset>,
}

impl IoJob for ExportSpringArchiveJob {
    fn run(self: Box<Self>) -> Box<dyn IoOutcome> {
        let job = *self;
        let output_path = job.output_path.clone();
        Box::new(match spring_archive::build(Spec {
            build_dir: job.build_dir,
            archive_dir: job.archive_dir,
            maps_dir: job.maps_dir,
            project_path: job.project_path,
            project_name: job.project_name,
            output_path: job.output_path,
            compiler_path: job.compiler_path,
            map_info: job.map_info,
            s11n_model: job.s11n_model,
            assets: job.assets,
        }) {
            Ok(()) => ExportSpringArchiveOutcome::Done { output_path },
            Err(reason) => ExportSpringArchiveOutcome::Failed { reason },
        })
    }
}

enum ExportSpringArchiveOutcome {
    Done { output_path: PathBuf },
    Failed { reason: String },
}

impl IoOutcome for ExportSpringArchiveOutcome {
    fn apply(self: Box<Self>, _sbc: &mut SBC) {
        match *self {
            ExportSpringArchiveOutcome::Done { output_path } => {
                info!("spring archive exported: {}", output_path.display());
            }
            ExportSpringArchiveOutcome::Failed { reason } => {
                error!("spring archive export failed: {reason}");
            }
        }
    }
}
