use std::path::PathBuf;

use log::debug;
use serde::Deserialize;

use crate::sbc::command_system::command::Command;
use crate::sbc::command_system::context::Context;
use crate::sbc::command_system::registry::register_command;
use crate::sbc::heightmap::model::heightmap_io::{heightmap_dims, HeightmapJob};

#[derive(Deserialize, Debug)]
pub struct LoadMapCommand {
    path: String,
}

impl Command for LoadMapCommand {
    fn execute(&mut self, ctx: &mut Context) {
        let Some((width, height)) = heightmap_dims(ctx.interface) else {
            log::error!("LoadMapCommand: could not read heightmap size");
            return;
        };

        let path = &self.path;
        debug!("LoadMapCommand: {path} ({width}x{height})");
        ctx.submit_io(Box::new(HeightmapJob::Load {
            path: PathBuf::from(path),
            width,
            height,
        }));
    }

    fn undoable(&self) -> bool {
        false
    }
}

register_command!(LoadMapCommand, "LoadMapCommand");
