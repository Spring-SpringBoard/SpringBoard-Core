use std::path::PathBuf;
use std::time::Duration;

use spring_native::constants::GAME_SQUARE_SIZE;

use crate::sbc::sbc::SBC;
use crate::sbc::tests::tests_api::TestCtx;

const SQUARE_SIZE: f32 = GAME_SQUARE_SIZE as f32;

fn grid_dims(sbc: &SBC) -> Result<(usize, usize), String> {
    let (points_x, points_z) = sbc
        .interface()
        .terrain()
        .get_height_map_size()
        .map_err(|e| format!("get_height_map_size: {e:?}"))?;
    Ok((points_x as usize, points_z as usize))
}

fn ground_height(sbc: &SBC, x: f32, z: f32) -> f32 {
    sbc.interface()
        .terrain()
        .get_ground_height(x, z)
        .unwrap_or(f32::MIN)
}

fn heightmap_import(ctx: &mut TestCtx) -> Result<(), String> {
    let (width, height) = grid_dims(ctx.sbc)?;

    let mut img =
        image::ImageBuffer::<image::Luma<u16>, Vec<u16>>::new(width as u32, height as u32);
    for x in 0..width as u32 {
        let lum = ((x as f32 / (width as u32 - 1).max(1) as f32) * 65535.0).round() as u16;
        for z in 0..height as u32 {
            img.put_pixel(x, z, image::Luma([lum]));
        }
    }
    let img_path = std::env::temp_dir().join("sbc_test_gradient.png");
    img.save(&img_path).map_err(|e| format!("save png: {e}"))?;

    let (min, max) = (100.0_f32, 200.0_f32);

    ctx.route_command(serde_json::json!({
        "className": "ImportHeightmapCommand",
        "heightmapImagePath": img_path.to_string_lossy(),
        "minHeight": min, "maxHeight": max,
    }));

    let settled = ctx.wait_for_io(Duration::from_secs(5), |sbc| {
        (ground_height(sbc, 0.0, 0.0) - min).abs() < 1.0
    });
    if !settled {
        return Err(format!(
            "import did not apply: left edge expected ~{min}, got {}",
            ground_height(ctx.sbc, 0.0, 0.0)
        ));
    }

    let right = ground_height(ctx.sbc, (width - 1) as f32 * SQUARE_SIZE, 0.0);
    if (right - max).abs() > 1.0 {
        return Err(format!("right edge: expected ~{max}, got {right}"));
    }
    Ok(())
}

fn heightmap_roundtrip(ctx: &mut TestCtx) -> Result<(), String> {
    let (width, height) = grid_dims(ctx.sbc)?;
    let (min, max) = (100.0_f32, 200.0_f32);
    let span = max - min;

    let value_at = |xi: usize, zi: usize| -> f32 {
        let fx = xi as f32 / width as f32;
        let fz = zi as f32 / height as f32;
        let n = (std::f32::consts::TAU * fx).sin() * 0.5
            + (std::f32::consts::TAU * fz * 1.5).sin() * 0.3
            + (std::f32::consts::TAU * (fx + fz)).cos() * 0.2;
        let frac = (n * 0.5 + 0.5).clamp(0.0, 1.0);
        min + frac * span
    };
    {
        let interface = ctx.sbc.interface();
        let synced = interface.synced_ctrl();
        let terrain = synced.terrain();
        for xi in 0..width {
            for zi in 0..height {
                let x = xi as f32 * SQUARE_SIZE;
                let z = zi as f32 * SQUARE_SIZE;
                let _ = terrain.set_height_map(x, z, value_at(xi, zi), 1.0);
            }
        }
    }

    let baseline: Vec<f32> = {
        let mut v = Vec::with_capacity(width * height);
        for xi in 0..width {
            for zi in 0..height {
                v.push(ground_height(
                    ctx.sbc,
                    xi as f32 * SQUARE_SIZE,
                    zi as f32 * SQUARE_SIZE,
                ));
            }
        }
        v
    };

    let out_png: PathBuf = std::env::temp_dir().join("sbc_test_roundtrip.png");
    let _ = std::fs::remove_file(&out_png);
    ctx.route_command(serde_json::json!({
        "className": "ExportHeightmapCommand",
        "path": out_png.to_string_lossy(),
        "heightmapExtremes": [min, max],
    }));
    let exported = ctx.wait_for_file(&out_png, Duration::from_secs(5));
    if !exported {
        return Err("export did not write the PNG".to_string());
    }

    {
        let interface = ctx.sbc.interface();
        let synced = interface.synced_ctrl();
        let terrain = synced.terrain();
        for xi in 0..width {
            for zi in 0..height {
                let _ = terrain.set_height_map(
                    xi as f32 * SQUARE_SIZE,
                    zi as f32 * SQUARE_SIZE,
                    0.0,
                    1.0,
                );
            }
        }
    }

    ctx.route_command(serde_json::json!({
        "className": "ImportHeightmapCommand",
        "heightmapImagePath": out_png.to_string_lossy(),
        "minHeight": min, "maxHeight": max,
    }));
    let s_idx = (width / 3) * height + (height / 3);
    let sample_x = (width / 3) as f32 * SQUARE_SIZE;
    let sample_z = (height / 3) as f32 * SQUARE_SIZE;
    let expected_sample = baseline[s_idx];
    let reimported = ctx.wait_for_io(Duration::from_secs(5), |sbc| {
        (ground_height(sbc, sample_x, sample_z) - expected_sample).abs() < span / 65535.0 * 3.0
    });
    if !reimported {
        return Err(format!(
            "re-import did not restore heights: at ({sample_x},{sample_z}) expected ~{expected_sample}, got {}",
            ground_height(ctx.sbc, sample_x, sample_z)
        ));
    }

    let tol = span / 65535.0 * 3.0;
    let mut max_err = 0.0_f32;
    let mut worst = (0.0_f32, 0.0_f32);
    let mut i = 0;
    for xi in 0..width {
        for zi in 0..height {
            let got = ground_height(ctx.sbc, xi as f32 * SQUARE_SIZE, zi as f32 * SQUARE_SIZE);
            let err = (got - baseline[i]).abs();
            if err > max_err {
                max_err = err;
                worst = (baseline[i], got);
            }
            i += 1;
        }
    }
    if max_err > tol {
        return Err(format!(
            "roundtrip max error {max_err:.3} exceeds tolerance {tol:.3} \
             (worst: baseline {:.3} vs reimport {:.3}, span {span}, 16-bit)",
            worst.0, worst.1
        ));
    }
    Ok(())
}

/// Write a `.data` heightmap file (LE `f32` per grid point) and load it via
/// `LoadMapCommand` with a path — the way project-load drives native.
fn heightmap_load(ctx: &mut TestCtx) -> Result<(), String> {
    let (width, height) = grid_dims(ctx.sbc)?;

    let value_at = |xi: usize| 100.0_f32 + xi as f32;
    let mut bytes = Vec::with_capacity(width * height * 4);
    for xi in 0..width {
        for _zi in 0..height {
            bytes.extend_from_slice(&value_at(xi).to_le_bytes());
        }
    }
    let path = std::env::temp_dir().join("sbc_test_load.data");
    std::fs::write(&path, &bytes).map_err(|e| format!("write .data: {e}"))?;

    let sample_xi = width / 2;
    let sample_x = sample_xi as f32 * SQUARE_SIZE;
    let expected = value_at(sample_xi);

    ctx.route_command(serde_json::json!({
        "className": "LoadMapCommand",
        "path": path.to_string_lossy(),
    }));

    let settled = ctx.wait_for_io(Duration::from_secs(5), |sbc| {
        (ground_height(sbc, sample_x, 0.0) - expected).abs() < 0.5
    });
    let _ = std::fs::remove_file(&path);
    if !settled {
        return Err(format!(
            "load did not apply: at x={sample_x} expected ~{expected}, got {}",
            ground_height(ctx.sbc, sample_x, 0.0)
        ));
    }
    Ok(())
}

/// `SaveMapCommand` writes a `.data` file sized for the whole map (one `f32` per
/// grid point). The exact byte content is covered by the pure save/load unit
/// test; here we just confirm the command drives the IO seam to disk.
fn heightmap_save(ctx: &mut TestCtx) -> Result<(), String> {
    let (width, height) = grid_dims(ctx.sbc)?;
    let path = std::env::temp_dir().join("sbc_test_save.data");
    let _ = std::fs::remove_file(&path);

    ctx.route_command(serde_json::json!({
        "className": "SaveMapCommand",
        "path": path.to_string_lossy(),
    }));
    if !ctx.wait_for_file(&path, Duration::from_secs(5)) {
        return Err("save did not write the .data file".to_string());
    }

    let len = std::fs::metadata(&path)
        .map(|m| m.len() as usize)
        .unwrap_or(0);
    let _ = std::fs::remove_file(&path);
    let expected = width * height * 4;
    if len != expected {
        return Err(format!("saved file is {len} bytes, expected {expected}"));
    }
    Ok(())
}

crate::integration_test!("heightmap_import", heightmap_import);
crate::integration_test!("heightmap_roundtrip", heightmap_roundtrip);
crate::integration_test!("heightmap_load", heightmap_load);
crate::integration_test!("heightmap_save", heightmap_save);
