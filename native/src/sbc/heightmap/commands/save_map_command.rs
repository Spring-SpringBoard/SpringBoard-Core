use std::path::PathBuf;

use log::debug;
use serde::Deserialize;
use spring_native::constants::GAME_SQUARE_SIZE;

use crate::sbc::command_system::command::Command;
use crate::sbc::command_system::context::Context;
use crate::sbc::command_system::registry::register_command;
use crate::sbc::heightmap::model::heightmap_io::{heightmap_dims, HeightmapJob};

const SQUARE_SIZE: f32 = GAME_SQUARE_SIZE as f32;

#[derive(Deserialize, Debug)]
pub struct SaveMapCommand {
    path: String,
}

impl Command for SaveMapCommand {
    fn execute(&mut self, ctx: &mut Context) {
        let Some((width, height)) = heightmap_dims(ctx.interface) else {
            log::error!("SaveMapCommand: could not read heightmap size");
            return;
        };

        let terrain = ctx.interface.terrain();
        let mut heights = Vec::with_capacity(width * height);
        for xi in 0..width {
            for zi in 0..height {
                let x = xi as f32 * SQUARE_SIZE;
                let z = zi as f32 * SQUARE_SIZE;
                heights.push(terrain.get_ground_height(x, z).unwrap_or(0.0));
            }
        }

        debug!("SaveMapCommand: {} ({}x{})", self.path, width, height);
        ctx.submit_io(Box::new(HeightmapJob::Save {
            path: PathBuf::from(self.path.clone()),
            heights,
        }));
    }

    fn undoable(&self) -> bool {
        false
    }
}

register_command!(SaveMapCommand, "SaveMapCommand");
