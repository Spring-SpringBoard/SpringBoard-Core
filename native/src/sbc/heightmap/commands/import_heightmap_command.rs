use std::path::PathBuf;

use serde::Deserialize;

use crate::sbc::command_system::command::Command;
use crate::sbc::command_system::context::Context;
use crate::sbc::command_system::registry::register_command;
use crate::sbc::heightmap::jobs;
use crate::sbc::heightmap::ops::{read, write, Heightmap};

#[derive(Deserialize, Debug)]
pub struct ImportHeightmapCommand {
    #[serde(rename = "heightmapImagePath")]
    heightmap_image_path: String,
    #[serde(rename = "minHeight")]
    min_height: f32,
    #[serde(rename = "maxHeight")]
    max_height: f32,
    // Pre-import heightmap, captured on first execute so undo can restore it.
    #[serde(skip)]
    before: Option<Heightmap>,
}

impl ImportHeightmapCommand {
    pub(crate) fn new(heightmap_image_path: String, min_height: f32, max_height: f32) -> Self {
        Self {
            heightmap_image_path,
            min_height,
            max_height,
            before: None,
        }
    }
}

impl Command for ImportHeightmapCommand {
    fn execute(&mut self, ctx: &mut Context) {
        // Import overwrites absolute heights, so snapshot the current map once
        // for undo (redo re-runs this execute and re-reads the image).
        if self.before.is_none() {
            self.before = read::read(ctx.interface);
        }
        jobs::import::submit(
            ctx,
            PathBuf::from(&self.heightmap_image_path),
            self.min_height,
            self.max_height,
        );
    }

    fn unexecute(&mut self, ctx: &mut Context) {
        if let Some(before) = &self.before {
            write::write(ctx.interface, before);
        }
    }
}

register_command!(ImportHeightmapCommand, "ImportHeightmapCommand");
