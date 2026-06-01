use std::collections::HashMap;
use std::f32::consts::PI;

use log::debug;
use serde::Deserialize;
use spring_native::prelude::*;

use super::brush_modify::{BrushModify, BrushOptions, Params};
use super::terrain_manager::TerrainManager;
use crate::sbc::commands::command_system::command::Command;
use crate::sbc::commands::command_system::context::Context;
use crate::sbc::commands::command_system::registry::register_command;

const SQUARE_SIZE: usize = 8;

#[derive(Deserialize, Debug)]
pub struct TerrainSmoothCommand {
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
    sigma: f32,
}

impl Command for TerrainSmoothCommand {
    fn execute(&mut self, ctx: &mut Context) {
        debug!("Command opts: {:?}", self.opts);
        self.stamp(false, ctx);
    }

    fn unexecute(&mut self, ctx: &mut Context) {
        self.stamp(true, ctx);
    }
}

impl TerrainSmoothCommand {
    fn stamp(&mut self, is_undo: bool, ctx: &mut Context) {
        let interface = *ctx.interface;
        let terrain_manager: &TerrainManager = ctx.terrain_manager;
        let sigma = self.opts.sigma;
        // One set_height_map_func batch so the engine recalcs the touched area
        // on return (see terrain_shape_modify_command.rs for why).
        let _ = interface.synced_ctrl().terrain().set_height_map_func(|| {
            self.brush().run(
                is_undo,
                terrain_manager,
                Self::generate_fn(interface, sigma),
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
        sigma: f32,
    ) -> impl FnOnce(Params) -> HashMap<usize, f32> {
        move |params| {
            let (kernel, kernel_size) = generate_kernel(sigma);
            let mut changes = HashMap::new();
            for x in (0..params.size).step_by(SQUARE_SIZE) {
                for z in (0..params.size).step_by(SQUARE_SIZE) {
                    let index = x as usize + z as usize * params.parts;
                    if params.map[&index] > 0.0 {
                        let global_x = x as f32 + params.start_x as f32;
                        let global_z = z as f32 + params.start_z as f32;
                        let (total, total_weight) =
                            kernel_total(interface, global_x, global_z, &kernel, kernel_size);
                        let total = total / total_weight;
                        let old = interface
                            .terrain()
                            .get_ground_height(global_x, global_z)
                            .unwrap_or(0.0);
                        if (total - old).abs() > f32::EPSILON {
                            changes.insert(index, total - old);
                        }
                    }
                }
            }
            changes
        }
    }
}

fn kernel_total(
    interface: NativeInterfaceRef,
    global_x: f32,
    global_z: f32,
    kernel: &[f32],
    kernel_size: usize,
) -> (f32, f32) {
    let mut total = 0.0;
    let mut total_weight = 0.0;
    let half = kernel_size as f32 / 2.0;
    let terrain = interface.terrain();
    for i in 0..kernel_size {
        for j in 0..kernel_size {
            let weight = kernel[i + j * kernel_size];
            let height = terrain
                .get_ground_height(
                    global_x + (i as f32 - half) * SQUARE_SIZE as f32,
                    global_z + (j as f32 - half) * SQUARE_SIZE as f32,
                )
                .unwrap_or(0.0);
            total += height * weight;
            total_weight += weight;
        }
    }
    (total, total_weight)
}

fn generate_kernel(sigma: f32) -> (Vec<f32>, usize) {
    let size = (sigma * 6.0).ceil() as usize;
    let size = if size.is_multiple_of(2) {
        size + 1
    } else {
        size
    };
    let half_size = (size as f32 / 2.0).ceil() as i32;

    let mut kernel = vec![0.0; size * size];
    let sigma_squared = sigma * sigma;
    for x in 0..size {
        for z in 0..size {
            let dx = half_size - x as i32;
            let dz = half_size - z as i32;
            let d = (dx * dx + dz * dz) as f32;
            kernel[x + z * size] =
                1.0 / (2.0 * PI * sigma_squared) * (-d / (2.0 * sigma_squared)).exp();
        }
    }
    (kernel, size)
}

register_command!(TerrainSmoothCommand, "TerrainSmoothCommand");
