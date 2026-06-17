use std::path::{Path, PathBuf};

use log::{error, info};
use spring_native::constants::GAME_SQUARE_SIZE;
use spring_native::prelude::NativeInterfaceRef;

use crate::sbc::io::io_api::{IoJob, IoOutcome};
use crate::sbc::sbc::SBC;

const SQUARE_SIZE: usize = GAME_SQUARE_SIZE as usize;

/// Heightmap grid point counts per axis, read from the engine.
pub fn heightmap_dims(interface: &NativeInterfaceRef) -> Option<(usize, usize)> {
    let (points_x, points_z) = interface.terrain().get_height_map_size().ok()?;
    Some((points_x as usize, points_z as usize))
}

pub enum HeightmapJob {
    Load {
        path: PathBuf,
        width: usize,
        height: usize,
    },
    Import {
        path: PathBuf,
        width: usize,
        height: usize,
        min: f32,
        max: f32,
    },
    Export {
        path: PathBuf,
        width: usize,
        height: usize,
        min: f32,
        max: f32,
        heights: Vec<f32>,
    },
    Save {
        path: PathBuf,
        heights: Vec<f32>,
    },
}

impl IoJob for HeightmapJob {
    fn run(self: Box<Self>) -> Box<dyn IoOutcome> {
        let outcome = match *self {
            HeightmapJob::Load {
                path,
                width,
                height,
            } => load_heightmap(&path, width, height),
            HeightmapJob::Import {
                path,
                width,
                height,
                min,
                max,
            } => import_heightmap(&path, width, height, min, max),
            HeightmapJob::Export {
                path,
                width,
                height,
                min,
                max,
                heights,
            } => export_heightmap(&path, width, height, min, max, &heights),
            HeightmapJob::Save { path, heights } => save_heightmap(&path, &heights),
        };
        Box::new(outcome)
    }
}

pub enum HeightmapOutcome {
    Loaded {
        width: usize,
        height: usize,
        heights: Vec<f32>,
    },
    Exported {
        path: PathBuf,
    },
    Saved {
        path: PathBuf,
    },
    Failed {
        job: &'static str,
        reason: String,
    },
}

impl IoOutcome for HeightmapOutcome {
    fn apply(self: Box<Self>, sbc: &mut SBC) {
        match *self {
            HeightmapOutcome::Loaded {
                width,
                height,
                heights,
            } => apply_heightmap(sbc, width, height, &heights),
            HeightmapOutcome::Exported { path } => {
                info!("export complete: {}", path.display());
            }
            HeightmapOutcome::Saved { path } => {
                info!("heightmap saved: {}", path.display());
            }
            HeightmapOutcome::Failed { job, reason } => {
                error!("IO job {job} failed: {reason}");
            }
        }
    }
}

fn apply_heightmap(sbc: &SBC, width: usize, height: usize, heights: &[f32]) {
    let synced = sbc.interface().synced_ctrl();
    let terrain = synced.terrain();
    // `set_height_map` alone mutates data without recalculating the rendered
    // terrain. The function wrapper is what makes the surface visibly update.
    let _ = terrain.set_height_map_func(|| {
        let mut i = 0;
        for xi in 0..width {
            for zi in 0..height {
                if i >= heights.len() {
                    break;
                }
                let x = (xi * SQUARE_SIZE) as f32;
                let z = (zi * SQUARE_SIZE) as f32;
                let _ = terrain.set_height_map(x, z, heights[i], 1.0);
                i += 1;
            }
        }
    });
}

pub(crate) fn export_heightmap(
    path: &Path,
    width: usize,
    height: usize,
    min: f32,
    max: f32,
    heights: &[f32],
) -> HeightmapOutcome {
    let span = (max - min).max(f32::EPSILON);
    let mut img =
        image::ImageBuffer::<image::Luma<u16>, Vec<u16>>::new(width as u32, height as u32);
    let mut i = 0;
    for xi in 0..width {
        for zi in 0..height {
            if i >= heights.len() {
                break;
            }
            let norm = ((heights[i] - min) / span).clamp(0.0, 1.0);
            let lum = (norm * 65535.0).round() as u16;
            img.put_pixel(xi as u32, zi as u32, image::Luma([lum]));
            i += 1;
        }
    }

    if let Err(err) = img.save(path) {
        return HeightmapOutcome::Failed {
            job: "ExportHeightmap",
            reason: format!("write {}: {err}", path.display()),
        };
    }
    HeightmapOutcome::Exported {
        path: path.to_path_buf(),
    }
}

pub(crate) fn import_heightmap(
    path: &Path,
    width: usize,
    height: usize,
    min: f32,
    max: f32,
) -> HeightmapOutcome {
    let img = match image::open(path) {
        Ok(i) => i,
        Err(err) => {
            return HeightmapOutcome::Failed {
                job: "ImportHeightmap",
                reason: format!("decode {}: {err}", path.display()),
            };
        }
    };

    // Only resample when the source grid differs, so a matching-size import is
    // exact (no interpolation smear).
    let luma = img.to_luma16();
    let scaled = if luma.dimensions() == (width as u32, height as u32) {
        luma
    } else {
        image::imageops::resize(
            &luma,
            width as u32,
            height as u32,
            image::imageops::FilterType::Triangle,
        )
    };

    let span = max - min;
    let mut heights = Vec::with_capacity(width * height);
    for xi in 0..width {
        for zi in 0..height {
            let lum = scaled.get_pixel(xi as u32, zi as u32).0[0] as f32 / 65535.0;
            heights.push(min + lum * span);
        }
    }

    HeightmapOutcome::Loaded {
        width,
        height,
        heights,
    }
}

pub(crate) fn load_heightmap(path: &Path, width: usize, height: usize) -> HeightmapOutcome {
    let expected = width * height;
    let bytes = match std::fs::read(path) {
        Ok(b) => b,
        Err(err) => {
            return HeightmapOutcome::Failed {
                job: "LoadHeightmap",
                reason: format!("read {}: {err}", path.display()),
            };
        }
    };

    if bytes.len() < expected * 4 {
        return HeightmapOutcome::Failed {
            job: "LoadHeightmap",
            reason: format!(
                "file {} has {} bytes, expected at least {} ({} floats)",
                path.display(),
                bytes.len(),
                expected * 4,
                expected
            ),
        };
    }

    let mut heights = Vec::with_capacity(expected);
    for chunk in bytes.chunks_exact(4).take(expected) {
        heights.push(f32::from_le_bytes([chunk[0], chunk[1], chunk[2], chunk[3]]));
    }

    HeightmapOutcome::Loaded {
        width,
        height,
        heights,
    }
}

pub(crate) fn save_heightmap(path: &Path, heights: &[f32]) -> HeightmapOutcome {
    let mut bytes = Vec::with_capacity(heights.len() * 4);
    for h in heights {
        bytes.extend_from_slice(&h.to_le_bytes());
    }
    match std::fs::write(path, &bytes) {
        Ok(()) => HeightmapOutcome::Saved {
            path: path.to_path_buf(),
        },
        Err(err) => HeightmapOutcome::Failed {
            job: "SaveHeightmap",
            reason: format!("write {}: {err}", path.display()),
        },
    }
}
