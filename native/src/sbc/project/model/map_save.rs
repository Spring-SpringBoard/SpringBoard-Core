use std::path::PathBuf;

use log::{error, info};
use spring_native::constants::GAME_SQUARE_SIZE;
use spring_native::prelude::NativeInterfaceRef;

use crate::sbc::io::io_api::{IoJob, IoOutcome};
use crate::sbc::message_handler::MessageHandler;
use crate::sbc::sbc::SBC;

inventory::submit! { MessageHandler { tag: "save_metal_map", handler: save_metal_map } }
inventory::submit! { MessageHandler { tag: "save_grass_map", handler: save_grass_map } }

/// Map units per metal-map cell. The metal map is `mapSize / METAL_RESOLUTION`
/// cells per axis (`save_command.lua`'s `METAL_RESOLUTION`).
const METAL_RESOLUTION: i32 = 16;

pub fn save_metal_map(sbc: &mut SBC, data: serde_json::Value) {
    let Some(path) = path_from_payload(&data, "save_metal_map") else {
        return;
    };
    let Some((size_x, size_z)) = map_size(sbc.interface()) else {
        error!("save_metal_map: could not read map size");
        return;
    };

    let metal = sbc.interface().metal_map();
    let mut bytes = Vec::new();
    let mut x = 0;
    while x < size_x {
        let rx = x / METAL_RESOLUTION;
        let mut z = 0;
        while z < size_z {
            let rz = z / METAL_RESOLUTION;
            let m = metal.get_metal_amount(rx, rz).unwrap_or(0.0);
            bytes.extend_from_slice(&m.to_le_bytes());
            z += METAL_RESOLUTION;
        }
        x += METAL_RESOLUTION;
    }

    submit(sbc, path, bytes, "metal map");
}

pub fn save_grass_map(sbc: &mut SBC, data: serde_json::Value) {
    // The grass map samples one cell per 4 height-map squares (Lua's
    // `gameSquareSize * 4`).
    const GRASS_STEP: i32 = GAME_SQUARE_SIZE * 4;
    let Some(path) = path_from_payload(&data, "save_grass_map") else {
        return;
    };
    let Some((size_x, size_z)) = map_size(sbc.interface()) else {
        error!("save_grass_map: could not read map size");
        return;
    };

    let terrain = sbc.interface().terrain();
    let mut bytes = Vec::new();
    let mut x = 0;
    while x < size_x {
        let mut z = 0;
        while z < size_z {
            let g = terrain.get_grass(x as f32, z as f32).unwrap_or(0.0);
            bytes.push(g as u8);
            z += GRASS_STEP;
        }
        x += GRASS_STEP;
    }

    submit(sbc, path, bytes, "grass map");
}

fn path_from_payload(data: &serde_json::Value, tag: &str) -> Option<PathBuf> {
    let Some(path) = data.get("path").and_then(|p| p.as_str()) else {
        error!("{tag}: missing 'path'");
        return None;
    };
    Some(PathBuf::from(path))
}

fn map_size(interface: &NativeInterfaceRef) -> Option<(i32, i32)> {
    let (mmx, mmz) = interface.metal_map().get_metal_map_size().ok()?;
    Some((mmx * METAL_RESOLUTION, mmz * METAL_RESOLUTION))
}

fn submit(sbc: &mut SBC, path: PathBuf, bytes: Vec<u8>, what: &'static str) {
    sbc.submit_io_job(Box::new(MapSaveJob { path, bytes, what }));
}

pub struct MapSaveJob {
    pub path: PathBuf,
    pub bytes: Vec<u8>,
    pub what: &'static str,
}

impl IoJob for MapSaveJob {
    fn run(self: Box<Self>) -> Box<dyn IoOutcome> {
        let outcome = match std::fs::write(&self.path, &self.bytes) {
            Ok(()) => MapSaveOutcome::Saved {
                what: self.what,
                path: self.path,
            },
            Err(err) => MapSaveOutcome::Failed {
                what: self.what,
                reason: format!("write {}: {err}", self.path.display()),
            },
        };
        Box::new(outcome)
    }
}

pub enum MapSaveOutcome {
    Saved { what: &'static str, path: PathBuf },
    Failed { what: &'static str, reason: String },
}

impl IoOutcome for MapSaveOutcome {
    fn apply(self: Box<Self>, _sbc: &mut SBC) {
        match *self {
            MapSaveOutcome::Saved { what, path } => {
                info!("{what} saved: {}", path.display());
            }
            MapSaveOutcome::Failed { what, reason } => {
                error!("{what} save failed: {reason}");
            }
        }
    }
}
