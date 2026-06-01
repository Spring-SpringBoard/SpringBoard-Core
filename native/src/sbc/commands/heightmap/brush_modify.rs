use std::collections::HashMap;

use ctrl_macros::some_or_return;

use super::brush_filter_generator::{get_map, Maps};
use super::terrain_manager::TerrainManager;

const SQUARE_SIZE: usize = 8;

/// Brush parameters shared by the four brush commands (shape / level / smooth /
/// metal). The command-specific behaviour is supplied as closures to
/// [`BrushModify::run`], not via inheritance.
#[derive(Clone, Debug)]
pub struct BrushOptions {
    pub x: f32,
    pub z: f32,
    pub size: f32,
    pub rotation: f32,
    pub strength: f32,
    pub shape_name: String,
}

/// Geometry of a brush stamp, passed to the per-command change generator.
pub struct Params {
    pub start_x: i32,
    pub start_z: i32,
    pub parts: usize,
    pub size: i32,
    pub is_undo: bool,
    pub map: HashMap<usize, f32>,
}

/// Composition helper for brush-based map editing. A command owns one of these,
/// supplies `generate` (compute per-point deltas) and `apply` (write one point)
/// closures, and calls `run(false, ...)` to execute / `run(true, ...)` to undo.
/// Changes are cached on first run so undo/redo replays them cheaply.
#[derive(Debug)]
pub struct BrushModify {
    opts: BrushOptions,
    changes: Option<HashMap<usize, f32>>,
    can_execute: Option<bool>,
}

impl BrushModify {
    pub fn new(mut opts: BrushOptions) -> Self {
        opts.x = opts.x.floor();
        opts.z = opts.z.floor();
        opts.size = opts.size.floor();
        Self {
            opts,
            changes: None,
            can_execute: None,
        }
    }

    /// Run the brush. `terrain_manager` provides the named greyscale shape;
    /// `generate` is called once (first execute) to compute the deltas (cached);
    /// subsequent execute/undo replay them (negated for undo). `apply` writes a
    /// single point. Skips entirely if the brush shape isn't loaded.
    pub fn run(
        &mut self,
        is_undo: bool,
        terrain_manager: &TerrainManager,
        generate: impl FnOnce(Params) -> HashMap<usize, f32>,
        apply: impl Fn(f32, f32, f32),
    ) {
        if self.can_execute.is_none() {
            self.can_execute = Some(terrain_manager.get_shape(&self.opts.shape_name).is_some());
        }
        if self.can_execute != Some(true) {
            // No SetHeightmapBrushCommand registered this shape — nothing to
            // stamp. Warn so the silent no-op is visible.
            log::warn!(
                "[brush] skipped: shape '{}' not loaded in Rust terrain_manager",
                self.opts.shape_name
            );
            return;
        }

        let opts = self.opts.clone();
        let rotation = opts.rotation.to_radians();
        let raw_size = opts.size;
        let rotated_size = get_rotated_size(raw_size, rotation);
        let orig_size = round_int(raw_size, SQUARE_SIZE as f32) as i32;
        let size = round_int(rotated_size, SQUARE_SIZE as f32) as i32;

        let mut maps = Maps::new();
        let map = {
            let greyscale = some_or_return!(terrain_manager.get_shape(&opts.shape_name));
            get_map(
                size as usize,
                opts.strength,
                &opts.shape_name,
                rotation,
                orig_size as f32,
                &mut maps,
                greyscale,
            )
        };

        let parts = size as usize / SQUARE_SIZE + 1;
        let dsh = round_int((size - orig_size) as f32 / 2.0, SQUARE_SIZE as f32) as i32;
        let start_x = round_int((opts.x as i32 - size + dsh) as f32, SQUARE_SIZE as f32) as i32;
        let start_z = round_int((opts.z as i32 - size + dsh) as f32, SQUARE_SIZE as f32) as i32;

        if !is_undo && self.changes.is_none() {
            self.changes = Some(generate(Params {
                start_x,
                start_z,
                parts,
                size,
                is_undo,
                map,
            }));
        }

        let Some(changes) = &self.changes else {
            return;
        };
        let sign = if is_undo { -1.0 } else { 1.0 };
        for x in (0..=size as usize).step_by(SQUARE_SIZE) {
            for z in (0..=size as usize).step_by(SQUARE_SIZE) {
                if let Some(delta) = changes.get(&(x + z * parts)) {
                    apply(
                        x as f32 + start_x as f32,
                        z as f32 + start_z as f32,
                        sign * delta,
                    );
                }
            }
        }
    }
}

fn round_int(x: f32, step: f32) -> f32 {
    (x.round() / step).floor() * step
}

fn get_rotated_size(size: f32, rotation: f32) -> f32 {
    size * (rotation.sin().abs() + rotation.cos().abs())
}
