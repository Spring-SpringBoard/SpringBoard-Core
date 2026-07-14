use std::collections::HashMap;

use log::debug;
use serde::{Deserialize, Serialize};
use spring_native::prelude::*;

use crate::sbc::command_system::command::Command;
use crate::sbc::command_system::context::Context;
use crate::sbc::command_system::registry::register_command;
use crate::sbc::heightmap::model::terrain_manager::TerrainManager;
use crate::sbc::terrain_cpu::brush_modify::{BrushModify, BrushOptions, Params};

const SQUARE_SIZE: usize = 8;

#[derive(Deserialize, Serialize, Debug)]
pub struct TerrainLevelCommand {
    opts: Opts,
    #[serde(skip)]
    brush: Option<BrushModify>,
}

#[derive(Deserialize, Serialize, Debug)]
pub(crate) struct Opts {
    pub(crate) rotation: f32,
    pub(crate) x: f32,
    pub(crate) z: f32,
    #[serde(rename = "shapeName")]
    pub(crate) shape_name: String,
    pub(crate) strength: f32,
    pub(crate) size: f32,
    pub(crate) height: f32,
    #[serde(rename = "applyDirID")]
    pub(crate) apply_dir_id: i32,
}

impl TerrainLevelCommand {
    pub(crate) fn new(opts: Opts) -> Self {
        Self { opts, brush: None }
    }
}

impl Command for TerrainLevelCommand {
    fn serialize_log(&self) -> serde_json::Value {
        serde_json::to_value(self).unwrap_or(serde_json::Value::Null)
    }

    fn execute(&mut self, ctx: &mut Context) {
        debug!("Command opts: {:?}", self.opts);
        self.stamp(false, ctx);
    }

    fn unexecute(&mut self, ctx: &mut Context) {
        self.stamp(true, ctx);
    }
}

impl TerrainLevelCommand {
    fn stamp(&mut self, is_undo: bool, ctx: &mut Context) {
        let interface = *ctx.interface;
        let terrain_manager: &TerrainManager = ctx.model::<TerrainManager>();
        let height = self.opts.height;
        let apply_dir_id = self.opts.apply_dir_id;
        // One set_height_map_func batch so the engine recalcs the touched area
        // on return (see terrain_shape_modify_command.rs for why).
        let _ = interface.synced_ctrl().terrain().set_height_map_func(|| {
            self.brush().run(
                is_undo,
                terrain_manager,
                Self::generate_fn(interface, height, apply_dir_id),
                |x, z, delta| {
                    let _ = interface
                        .synced_ctrl()
                        .terrain()
                        .add_height_map(x, z, delta);
                },
            );
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

    fn generate_fn(
        interface: NativeInterfaceRef,
        height: f32,
        apply_dir_id: i32,
    ) -> impl FnOnce(Params) -> HashMap<usize, f32> {
        move |params| {
            let Params {
                start_x,
                start_z,
                parts,
                size,
                map,
                ..
            } = params;
            let can_upper = apply_dir_id >= 0;
            let can_lower = apply_dir_id <= 0;

            let mut changes = HashMap::new();
            for x in (0..=size).step_by(SQUARE_SIZE) {
                for z in (0..=size).step_by(SQUARE_SIZE) {
                    let index = x as usize + z as usize * parts;
                    let d = map[&index];
                    if d > 0.0 {
                        let terrain = interface.terrain();
                        let old = terrain
                            .get_ground_height((x + start_x) as f32, (z + start_z) as f32)
                            .unwrap_or(0.0);
                        if height > old {
                            if can_upper {
                                changes.insert(index, d.min(height - old));
                            }
                        } else if can_lower {
                            changes.insert(index, -d.min(old - height));
                        }
                    }
                }
            }
            changes
        }
    }
}

register_command!(TerrainLevelCommand, "TerrainLevelCommand");
