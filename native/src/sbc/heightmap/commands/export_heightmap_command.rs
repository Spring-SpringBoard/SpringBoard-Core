use std::path::PathBuf;

use serde::Deserialize;

use crate::sbc::command_system::command::Command;
use crate::sbc::command_system::context::Context;
use crate::sbc::command_system::registry::register_command;
use crate::sbc::heightmap::jobs;

#[derive(Deserialize, Debug)]
pub struct ExportHeightmapCommand {
    path: String,
    #[serde(default, rename = "heightmapExtremes")]
    heightmap_extremes: Option<Vec<f32>>,
}

impl ExportHeightmapCommand {
    pub(crate) fn new(path: String) -> Self {
        Self {
            path,
            heightmap_extremes: None,
        }
    }
}

impl Command for ExportHeightmapCommand {
    fn execute(&mut self, ctx: &mut Context) {
        jobs::export::submit(
            ctx,
            PathBuf::from(&self.path),
            self.heightmap_extremes.clone(),
        );
    }

    fn undoable(&self) -> bool {
        false
    }
}

register_command!(ExportHeightmapCommand, "ExportHeightmapCommand");
