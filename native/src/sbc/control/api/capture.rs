//! `capture`: the barrier. Its reply waits for the image, so whatever a client
//! did before it is in the frame.

use std::path::PathBuf;

use serde::Deserialize;

use crate::sbc::project::ScreenshotManager;
use crate::sbc::sbc::SBC;

use super::super::channel::Effect;
use super::super::{ControlError, Handled, Reply};

#[derive(Deserialize)]
pub(crate) struct Capture {
    pub path: PathBuf,
}

pub(crate) fn capture(sbc: &mut SBC, params: Capture) -> Handled {
    if params.path.is_relative() {
        return Err(ControlError::invalid(
            "capture needs an absolute path: the engine resolves relative ones against its own working directory",
        ));
    }
    let _ = std::fs::remove_file(&params.path);
    sbc.model::<ScreenshotManager>()
        .request_e2e(params.path.clone());
    Ok(Reply::When(Effect::Capture(params.path)))
}
