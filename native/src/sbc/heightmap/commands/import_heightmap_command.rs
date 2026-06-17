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
pub struct ImportHeightmapCommand {
    #[serde(rename = "heightmapImagePath")]
    heightmap_image_path: String,
    #[serde(rename = "minHeight")]
    min_height: f32,
    #[serde(rename = "maxHeight")]
    max_height: f32,
    // Pre-import heightmap, captured on first execute so undo can restore it.
    #[serde(skip)]
    before: Option<Vec<f32>>,
}

impl Command for ImportHeightmapCommand {
    fn execute(&mut self, ctx: &mut Context) {
        let Some((width, height)) = heightmap_dims(ctx.interface) else {
            log::error!("ImportHeightmapCommand: could not read heightmap size");
            return;
        };

        // Import overwrites absolute heights, so snapshot the current map once
        // for undo (redo re-runs this execute and re-reads the image).
        if self.before.is_none() {
            let terrain = ctx.interface.terrain();
            let mut snapshot = Vec::with_capacity(width * height);
            for xi in 0..width {
                for zi in 0..height {
                    let (x, z) = (xi as f32 * SQUARE_SIZE, zi as f32 * SQUARE_SIZE);
                    snapshot.push(terrain.get_ground_height(x, z).unwrap_or(0.0));
                }
            }
            self.before = Some(snapshot);
        }

        let path = &self.heightmap_image_path;
        let (min, max) = (self.min_height, self.max_height);
        debug!(
            "ImportHeightmapCommand: {} ({}x{}) -> [{}, {}]",
            path, width, height, min, max
        );
        ctx.submit_io(Box::new(HeightmapJob::Import {
            path: PathBuf::from(path),
            width,
            height,
            min,
            max,
        }));
    }

    fn unexecute(&mut self, ctx: &mut Context) {
        let Some(before) = self.before.as_ref() else {
            return;
        };
        let Some((width, height)) = heightmap_dims(ctx.interface) else {
            return;
        };
        let synced = ctx.interface.synced_ctrl();
        let terrain = synced.terrain();
        let _ = terrain.set_height_map_func(|| {
            let mut i = 0;
            for xi in 0..width {
                for zi in 0..height {
                    if i >= before.len() {
                        break;
                    }
                    let (x, z) = (xi as f32 * SQUARE_SIZE, zi as f32 * SQUARE_SIZE);
                    let _ = terrain.set_height_map(x, z, before[i], 1.0);
                    i += 1;
                }
            }
        });
    }
}

register_command!(ImportHeightmapCommand, "ImportHeightmapCommand");
