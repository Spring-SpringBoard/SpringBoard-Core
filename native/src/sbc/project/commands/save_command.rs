use std::path::PathBuf;

use serde::Deserialize;

use crate::sbc::command_system::command::Command;
use crate::sbc::command_system::context::Context;
use crate::sbc::command_system::registry::register_command;
use crate::sbc::project::io_registries::save;
use crate::sbc::project::paths::ProjectPaths;
use crate::sbc::project::ScreenshotManager;

const SCREENSHOT_FILE: &str = "screenshot.jpg";

#[derive(Deserialize, Debug)]
pub struct SaveCommand {
    path: String,
    #[serde(default, rename = "isNewProject")]
    is_new_project: bool,
}

impl SaveCommand {
    pub(crate) fn new(path: String, is_new_project: bool) -> Self {
        Self {
            path,
            is_new_project,
        }
    }
}

impl Command for SaveCommand {
    fn execute(&mut self, ctx: &mut Context) {
        let root = PathBuf::from(&self.path);
        save::save_project(ctx, &root, self.is_new_project);
        // Grab a fresh map thumbnail for the Open dialog. The framebuffer can
        // only be read on the draw thread, so record the request and let the
        // next DrawScreen write it.
        let path = ProjectPaths::new(&root).file(SCREENSHOT_FILE);
        ctx.model::<ScreenshotManager>().request(path);
    }

    fn undoable(&self) -> bool {
        false
    }
}

register_command!(SaveCommand, "SaveCommand");
