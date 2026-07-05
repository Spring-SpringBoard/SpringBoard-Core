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

crate::integration_test!("heightmap_import", heightmap_import);
crate::integration_test!("heightmap_roundtrip", heightmap_roundtrip);
