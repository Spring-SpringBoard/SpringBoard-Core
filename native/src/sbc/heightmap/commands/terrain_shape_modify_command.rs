use std::collections::HashMap;

use log::debug;
use serde::Deserialize;

use crate::sbc::heightmap::model::brush_modify::{BrushModify, BrushOptions, Params};
use crate::sbc::heightmap::model::terrain_manager::TerrainManager;
use crate::sbc::command_system::command::Command;
use crate::sbc::command_system::context::Context;
use crate::sbc::command_system::registry::register_command;

const SQUARE_SIZE: usize = 8;

#[derive(Deserialize, Debug)]
pub struct TerrainShapeModifyCommand {
    opts: Opts,
    #[serde(skip)]
    brush: Option<BrushModify>,
}

#[derive(Deserialize, Debug)]
struct Opts {
    rotation: f32,
    x: f32,
    z: f32,
    #[serde(rename = "shapeName")]
    shape_name: String,
    strength: f32,
    size: f32,
}

impl Command for TerrainShapeModifyCommand {
    fn execute(&mut self, ctx: &mut Context) {
        debug!("Command opts: {:?}", self.opts);
        self.stamp(false, ctx);
    }

    fn unexecute(&mut self, ctx: &mut Context) {
        self.stamp(true, ctx);
    }
}

impl TerrainShapeModifyCommand {
    fn stamp(&mut self, is_undo: bool, ctx: &mut Context) {
        let interface = *ctx.interface;
        let terrain_manager: &TerrainManager = ctx.model::<TerrainManager>();
        // Wrap the per-point writes in one set_height_map_func batch: the engine
        // recalcs the touched area on return (UpdateFaceNormals + LOS/pathing),
        // so the change becomes visible and affects simulation. Raw
        // add_height_map alone changes data but never recalcs.
        let _ = interface.synced_ctrl().terrain().set_height_map_func(|| {
            self.brush()
                .run(is_undo, terrain_manager, generate_changes, |x, z, delta| {
                    let _ = interface
                        .synced_ctrl()
                        .terrain()
                        .add_height_map(x, z, delta);
                });
        });
    }

    fn brush(&mut self) -> &mut BrushModify {
        self.brush.get_or_insert_with(|| {
            BrushModify::new(BrushOptions {
                x: self.opts.x,
                z: self.opts.z,
                size: self.opts.size,
                rotation: self.opts.rotation,
                strength: self.opts.strength,
                shape_name: self.opts.shape_name.clone(),
            })
        })
    }
}

fn generate_changes(params: Params) -> HashMap<usize, f32> {
    let Params {
        start_x,
        start_z,
        parts,
        size,
        map,
        is_undo,
    } = params;

    let offset_x = if start_x < 0 {
        -start_x + start_x % SQUARE_SIZE as i32
    } else {
        0
    };
    let offset_z = if start_z < 0 {
        -start_z + start_z % SQUARE_SIZE as i32
    } else {
        0
    };
    let multiplier = if is_undo { -1.0 } else { 1.0 };

    let mut changes = HashMap::new();
    for x in (offset_x..=size).step_by(SQUARE_SIZE) {
        for z in (offset_z..=size).step_by(SQUARE_SIZE) {
            let index = x as usize + z as usize * parts;
            changes.insert(index, map[&index] * multiplier);
        }
    }
    changes
}

register_command!(TerrainShapeModifyCommand, "TerrainShapeModifyCommand");
