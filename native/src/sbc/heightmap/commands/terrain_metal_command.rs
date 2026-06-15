use crate::sbc::heightmap::TerrainManager;
use std::collections::HashMap;

use log::debug;
use serde::Deserialize;
use spring_native::prelude::*;

use crate::sbc::command_system::command::Command;
use crate::sbc::command_system::context::Context;
use crate::sbc::command_system::registry::register_command;
use crate::sbc::heightmap::model::brush_modify::{BrushModify, BrushOptions, Params};

const METAL_RESOLUTION: usize = 16;

#[derive(Deserialize, Debug)]
pub struct TerrainMetalCommand {
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

impl Command for TerrainMetalCommand {
    fn execute(&mut self, ctx: &mut Context) {
        debug!("Command opts: {:?}", self.opts);
        self.stamp(false, ctx);
    }

    fn unexecute(&mut self, ctx: &mut Context) {
        self.stamp(true, ctx);
    }
}

impl TerrainMetalCommand {
    // No set_height_map_func wrapper (unlike the height brushes): the metal map
    // needs no recalc — set_metal_amount takes effect directly.
    fn stamp(&mut self, is_undo: bool, ctx: &mut Context) {
        let interface = *ctx.interface;
        let amount = self.opts.amount;
        self.brush().run(
            is_undo,
            ctx.model::<TerrainManager>(),
            Self::generate_fn(interface, amount),
            move |x, z, amount| {
                let rx = (x / METAL_RESOLUTION as f32).round() as i32;
                let rz = (z / METAL_RESOLUTION as f32).round() as i32;
                let metal_map = interface.metal_map();
                let old = metal_map.get_metal_amount(rx, rz).unwrap_or(0.0);
                let _ = metal_map.set_metal_amount(rx, rz, old + amount);
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
            let metal_map = interface.metal_map();
            let mut changes = HashMap::new();
            for x in (0..=size).step_by(METAL_RESOLUTION) {
                let rx = ((x + start_x) as usize) / METAL_RESOLUTION;
                for z in (0..=size).step_by(METAL_RESOLUTION) {
                    let rz = ((z + start_z) as usize) / METAL_RESOLUTION;
                    let index = x as usize + z as usize * parts;
                    let multiplier = map[&index];
                    if multiplier > 0.0 {
                        let old = metal_map
                            .get_metal_amount(rx as i32, rz as i32)
                            .unwrap_or(0.0);
                        let delta = (amount - old) * multiplier;
                        if delta != 0.0 {
                            changes.insert(index, delta);
                        }
                    }
                }
            }
            changes
        }
    }
}

register_command!(TerrainMetalCommand, "TerrainMetalCommand");
