use std::path::Path;

use crate::sbc::heightmap::model::heightmap_io::{
    export_heightmap, import_heightmap, HeightmapOutcome,
};

// A PNG export followed by an import recovers the original heights within the
// 16-bit quantization step. Pure (no engine), unlike the in-engine roundtrip.
#[test]
fn export_then_import_roundtrips_within_quantization() {
    let (width, height) = (16usize, 12usize);
    let (min, max) = (100.0_f32, 200.0_f32);

    let original = ramp(width, height, min, max);
    let path = std::env::temp_dir().join("sbc_unit_roundtrip.png");
    let _ = std::fs::remove_file(&path);

    write_png(&path, width, height, min, max, &original);
    let heights = read_png(&path, width, height, min, max);

    assert_eq!(heights.len(), width * height);
    let tol = (max - min) / 65535.0 * 2.0;
    for (a, b) in original.iter().zip(heights.iter()) {
        assert!((a - b).abs() <= tol, "roundtrip {a} vs {b}, tol {tol}");
    }
    let _ = std::fs::remove_file(&path);
}

fn ramp(width: usize, height: usize, min: f32, max: f32) -> Vec<f32> {
    let span = max - min;
    let mut heights = Vec::with_capacity(width * height);
    for xi in 0..width {
        for zi in 0..height {
            let frac = (xi as f32 / width as f32 + zi as f32 / height as f32) / 2.0;
            heights.push(min + frac * span);
        }
    }
    heights
}

fn write_png(path: &Path, width: usize, height: usize, min: f32, max: f32, heights: &[f32]) {
    match export_heightmap(path, width, height, min, max, heights) {
        HeightmapOutcome::Exported { .. } => {}
        other => panic!("export failed: {}", outcome_kind(&other)),
    }
}

fn read_png(path: &Path, width: usize, height: usize, min: f32, max: f32) -> Vec<f32> {
    match import_heightmap(path, width, height, min, max) {
        HeightmapOutcome::Loaded { heights, .. } => heights,
        other => panic!("import failed: {}", outcome_kind(&other)),
    }
}

fn outcome_kind(outcome: &HeightmapOutcome) -> &'static str {
    match outcome {
        HeightmapOutcome::Loaded { .. } => "Loaded",
        HeightmapOutcome::Exported { .. } => "Exported",
        HeightmapOutcome::Saved { .. } => "Saved",
        HeightmapOutcome::Failed { .. } => "Failed",
    }
}
