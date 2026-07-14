use serde::Deserialize;

use crate::sbc::command_system::command::Command;
use crate::sbc::command_system::context::Context;
use crate::sbc::command_system::io_completion;
use crate::sbc::command_system::registry::register_command;
use crate::sbc::project::io_registries::export::{self, MapExportOptions};

#[derive(Deserialize, Debug)]
pub struct ExportMapsCommand {
    path: String,
    #[serde(default, rename = "heightmapExtremes")]
    heightmap_extremes: Option<Vec<f32>>,
}

impl ExportMapsCommand {
    pub(crate) fn new(path: String) -> Self {
        Self {
            path,
            heightmap_extremes: None,
        }
    }
}

impl Command for ExportMapsCommand {
    fn execute(&mut self, ctx: &mut Context) {
        export::export_maps(
            ctx,
            self.path.as_ref(),
            &MapExportOptions {
                heightmap_extremes: self.heightmap_extremes.clone(),
            },
        );
        io_completion::submit_native_command_completed(ctx);
    }

    fn undoable(&self) -> bool {
        false
    }
}

register_command!(ExportMapsCommand, "ExportMapsCommand");
