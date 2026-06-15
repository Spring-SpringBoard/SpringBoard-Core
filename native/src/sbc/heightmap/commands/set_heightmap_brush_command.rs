use crate::sbc::heightmap::TerrainManager;
use std::collections::HashMap;

use ctrl_macros::ok_or;
use log::{debug, error};
use serde::Deserialize;

use crate::sbc::command_system::command::Command;
use crate::sbc::command_system::context::Context;
use crate::sbc::command_system::hashmap_to_vector::hashmap_to_vector;
use crate::sbc::command_system::registry::register_command;
use crate::sbc::heightmap::model::terrain_manager::GreyscaleShape;

// TODO: Load directly in Rust so we don't need to pass these large arrays
#[derive(Deserialize, Debug)]
pub struct SetHeightmapBrushCommand {
    greyscale: SetHeightmapBrushCommandOpts,
}

#[derive(Deserialize, Debug)]
pub struct SetHeightmapBrushCommandOpts {
    pub res: HashMap<usize, f32>,
    #[serde(rename = "sizeX")]
    pub size_x: usize,
    #[serde(rename = "sizeZ")]
    pub size_z: usize,
    pub name: String,
}

impl Command for SetHeightmapBrushCommand {
    fn execute(&mut self, ctx: &mut Context) {
        debug!("{:?}", self.greyscale);

        let greyscale = ok_or!(hashmap_to_vector(&self.greyscale.res), {
            error!("Error parsing greyscale component of SetHeightmapBrushCommand");
            return;
        });

        ctx.model::<TerrainManager>().shapes.insert(
            std::mem::take(&mut self.greyscale.name),
            GreyscaleShape {
                size_x: self.greyscale.size_x,
                size_z: self.greyscale.size_z,
                res: greyscale,
            },
        );
    }

    fn undoable(&self) -> bool {
        false
    }
}

register_command!(SetHeightmapBrushCommand, "SetHeightmapBrushCommand");
