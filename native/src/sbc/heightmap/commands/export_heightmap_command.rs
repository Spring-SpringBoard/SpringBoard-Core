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
pub struct ExportHeightmapCommand {
    path: String,
    #[serde(default, rename = "heightmapExtremes")]
    heightmap_extremes: Option<Vec<f32>>,
}

impl Command for ExportHeightmapCommand {
    fn execute(&mut self, ctx: &mut Context) {
        let Some((width, height)) = heightmap_dims(ctx.interface) else {
            log::error!("ExportHeightmapCommand: could not read heightmap size");
            return;
        };

        let mut heights = Vec::with_capacity(width * height);
        let terrain = ctx.interface.terrain();
        for xi in 0..width {
            for zi in 0..height {
                let x = xi as f32 * SQUARE_SIZE;
                let z = zi as f32 * SQUARE_SIZE;
                heights.push(terrain.get_ground_height(x, z).unwrap_or(0.0));
            }
        }

        // Use the given extremes if any, else the actual height range.
        let (min, max) = match self.heightmap_extremes.as_deref() {
            Some(&[min, max, ..]) => (min, max),
            _ => extremes_from_heights(&heights),
        };

        debug!(
            "ExportHeightmapCommand: {} ({}x{}) [{}, {}]",
            self.path, width, height, min, max
        );
        ctx.submit_io(Box::new(HeightmapJob::Export {
            path: PathBuf::from(self.path.clone()),
            width,
            height,
            min,
            max,
            heights,
        }));
    }

    fn undoable(&self) -> bool {
        false
    }
}

fn extremes_from_heights(heights: &[f32]) -> (f32, f32) {
    heights
        .iter()
        .copied()
        .fold((f32::INFINITY, f32::NEG_INFINITY), |(min, max), h| {
            (min.min(h), max.max(h))
        })
}

register_command!(ExportHeightmapCommand, "ExportHeightmapCommand");
