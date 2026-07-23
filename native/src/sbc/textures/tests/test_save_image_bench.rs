use std::cell::Cell;
use std::path::Path;
use std::time::Instant;

use serde::Serialize;
use spring_native::prelude::constants;

use super::test_support::artifact_dir;
use crate::sbc::tests::tests_api::TestCtx;
use crate::sbc::textures::model::graphics::{self, Texture};

const DIMENSIONS: &[i32] = &[1024, 2048, 4096];
const FORMATS: &[&str] = &["bmp", "dds", "png", "raw"];
const SAMPLES: usize = 3;

#[derive(Serialize)]
struct SaveImageBenchmark {
    cases: Vec<SaveImageBenchmarkCase>,
}

#[derive(Serialize)]
struct SaveImageBenchmarkCase {
    width: i32,
    height: i32,
    format: &'static str,
    output: String,
    bytes: Option<u64>,
    samples_ms: Vec<f64>,
    min_ms: Option<f64>,
    median_ms: Option<f64>,
    max_ms: Option<f64>,
    error: Option<String>,
}

fn save_image_bench(ctx: &mut TestCtx) -> Result<(), String> {
    let output_dir = artifact_dir().join("save-image-bench");
    std::fs::create_dir_all(&output_dir)
        .map_err(|error| format!("create {}: {error}", output_dir.display()))?;

    let mut cases = Vec::new();
    for &dimension in DIMENSIONS {
        let texture = create_source_texture(ctx, dimension)?;
        for &format in FORMATS {
            cases.push(benchmark_case(
                ctx,
                &texture,
                dimension,
                format,
                &output_dir,
            ));
        }
        let _ = ctx.sbc.interface().gfx().delete_texture(&texture);
    }

    let report = SaveImageBenchmark { cases };
    write_report(&output_dir, &report)?;
    let failures: Vec<String> = report
        .cases
        .iter()
        .filter_map(|case| {
            case.error
                .as_ref()
                .map(|error| format!("{}x{} .{}: {error}", case.width, case.height, case.format))
        })
        .collect();
    if failures.is_empty() {
        Ok(())
    } else {
        Err(failures.join("; "))
    }
}

fn create_source_texture(ctx: &TestCtx, dimension: i32) -> Result<Texture, String> {
    let interface = *ctx.sbc.interface();
    let texture = graphics::create_fbo_texture(&interface, dimension, dimension)
        .ok_or_else(|| format!("create {dimension}x{dimension} source texture"))?;
    let pixels = source_pixels(dimension);
    interface
        .gfx()
        .upload_texture(
            &texture,
            constants::GL_TEXTURE_2D,
            0,
            0,
            0,
            0,
            dimension,
            dimension,
            1,
            constants::GL_RGBA,
            constants::GL_UNSIGNED_BYTE,
            &pixels,
        )
        .map_err(|error| format!("upload {dimension}x{dimension} source texture: {error:?}"))?;
    Ok(texture)
}

fn benchmark_case(
    ctx: &TestCtx,
    texture: &Texture,
    dimension: i32,
    format: &'static str,
    output_dir: &Path,
) -> SaveImageBenchmarkCase {
    let output = output_dir.join(format!("{dimension}x{dimension}.{format}"));
    let mut samples_ms = Vec::with_capacity(SAMPLES);
    let mut error = save_once(ctx, texture, dimension, &output).err();
    if error.is_none() {
        for _ in 0..SAMPLES {
            match save_once(ctx, texture, dimension, &output) {
                Ok(elapsed_ms) => samples_ms.push(elapsed_ms),
                Err(save_error) => {
                    error = Some(save_error);
                    break;
                }
            }
        }
    }

    let mut sorted_ms = samples_ms.clone();
    sorted_ms.sort_by(f64::total_cmp);
    SaveImageBenchmarkCase {
        width: dimension,
        height: dimension,
        format,
        output: output
            .file_name()
            .unwrap_or_default()
            .to_string_lossy()
            .into_owned(),
        bytes: error
            .is_none()
            .then(|| std::fs::metadata(&output).map(|meta| meta.len()).ok())
            .flatten(),
        min_ms: sorted_ms.first().copied(),
        median_ms: sorted_ms.get(sorted_ms.len() / 2).copied(),
        max_ms: sorted_ms.last().copied(),
        samples_ms,
        error,
    }
}

fn save_once(
    ctx: &TestCtx,
    texture: &Texture,
    dimension: i32,
    output: &Path,
) -> Result<f64, String> {
    ctx.heartbeat();
    let output_path = output
        .to_str()
        .ok_or_else(|| format!("non-utf8 output path {}", output.display()))?;
    let save_error = Cell::new(None);
    let started = Instant::now();
    ctx.sbc
        .interface()
        .gfx()
        .render_to_texture(texture, || {
            match ctx.sbc.interface().gfx().save_image(
                0,
                0,
                dimension,
                dimension,
                output_path,
                true,
                false,
                false,
                0,
            ) {
                Ok(true) => {}
                Ok(false) => save_error.set(Some(format!(
                    "save_image returned false for {}",
                    output.display()
                ))),
                Err(error) => {
                    save_error.set(Some(format!("save_image {}: {error:?}", output.display())))
                }
            }
        })
        .map_err(|error| format!("render_to_texture {}: {error:?}", output.display()))?;
    if let Some(error) = save_error.take() {
        return Err(error);
    }
    if !output.is_file() {
        return Err(format!("save_image did not create {}", output.display()));
    }
    ctx.heartbeat();
    Ok(started.elapsed().as_secs_f64() * 1_000.0)
}

fn source_pixels(dimension: i32) -> Vec<u8> {
    let pixel_count = usize::try_from(dimension).unwrap_or_default().pow(2);
    let mut pixels = Vec::with_capacity(pixel_count * 4);
    for index in 0..pixel_count {
        let value = index as u32;
        pixels.extend_from_slice(&[
            hash_byte(value.wrapping_mul(3)),
            hash_byte(value.wrapping_mul(3).wrapping_add(1)),
            hash_byte(value.wrapping_mul(3).wrapping_add(2)),
            255,
        ]);
    }
    pixels
}

fn hash_byte(mut value: u32) -> u8 {
    value ^= value >> 16;
    value = value.wrapping_mul(0x7feb_352d);
    value ^= value >> 15;
    value = value.wrapping_mul(0x846c_a68b);
    (value ^ (value >> 16)) as u8
}

fn write_report(output_dir: &Path, report: &SaveImageBenchmark) -> Result<(), String> {
    let path = output_dir.join("report.json");
    let json = serde_json::to_string_pretty(report)
        .map_err(|error| format!("serialize report: {error}"))?;
    std::fs::write(&path, format!("{json}\n"))
        .map_err(|error| format!("write {}: {error}", path.display()))
}

crate::integration_test!("save_image_bench", save_image_bench, opt_in = true);
