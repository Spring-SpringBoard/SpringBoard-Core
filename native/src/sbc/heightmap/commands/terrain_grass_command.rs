use crate::sbc::heightmap::TerrainManager;
use std::collections::HashMap;

use log::debug;
use serde::Deserialize;
use spring_native::prelude::*;

use crate::sbc::command_system::command::Command;
use crate::sbc::command_system::context::Context;
use crate::sbc::command_system::registry::register_command;
use crate::sbc::heightmap::model::brush_modify::{BrushModify, BrushOptions, Params};

const GRASS_STEP: usize = 8 * 4;

#[derive(Deserialize, Debug)]
pub struct TerrainGrassCommand {
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
    amount: f32,
    size: f32,
}

impl Command for TerrainGrassCommand {
    fn execute(&mut self, ctx: &mut Context) {
        debug!("Command opts: {:?}", self.opts);
        self.stamp(false, ctx);
    }

    fn unexecute(&mut self, ctx: &mut Context) {
        self.stamp(true, ctx);
    }
}

impl TerrainGrassCommand {
    fn stamp(&mut self, is_undo: bool, ctx: &mut Context) {
        let interface = *ctx.interface;
        let amount = self.opts.amount.max(0.0);
        self.brush().run_with_step(
            is_undo,
            ctx.model::<TerrainManager>(),
            GRASS_STEP,
            Self::generate_fn(interface, amount),
            move |x, z, delta| {
                let synced = interface.synced_ctrl();
                let terrain = synced.terrain();
                if delta > 0.0 {
                    let _ = terrain.add_grass(x, z);
                } else {
                    let _ = terrain.remove_grass(x, z);
                }
            },
        );
    }

    fn brush(&mut self) -> &mut BrushModify {
        self.brush.get_or_insert_with(|| {
            BrushModify::new(BrushOptions {
                x: self.opts.x,
                z: self.opts.z,
                size: self.opts.size,
                rotation: self.opts.rotation,
                strength: 1.0,
                shape_name: self.opts.shape_name.clone(),
            })
        })
    }

    fn generate_fn(
        interface: NativeInterfaceRef,
        amount: f32,
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
            let terrain = interface.terrain();
            let mut changes = HashMap::new();
            for x in (0..=size).step_by(GRASS_STEP) {
                for z in (0..=size).step_by(GRASS_STEP) {
                    let index = x as usize + z as usize * parts;
                    if map[&index] >= 0.5 {
                        let old = terrain
                            .get_grass((start_x + x) as f32, (start_z + z) as f32)
                            .unwrap_or(0.0);
                        if (old - amount).abs() > f32::EPSILON {
                            changes.insert(index, amount - old);
                        }
                    }
                }
            }
            changes
        }
    }
}

register_command!(TerrainGrassCommand, "TerrainGrassCommand");
