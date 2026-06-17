use std::path::Path;

use crate::sbc::heightmap::model::heightmap_io::{
    load_heightmap, save_heightmap, HeightmapOutcome,
};

// Saving heights to a `.data` file and loading them back returns every value
// bit-for-bit (raw `f32`, no quantization). Pure — no engine — so it covers the
// whole map and any value range, including what the engine would clamp.
#[test]
fn save_then_load_roundtrips_exactly() {
    let (width, height) = (640usize, 512usize);
    let original = sample_heights(width, height);

    let path = std::env::temp_dir().join("sbc_unit_save_load.data");
    let _ = std::fs::remove_file(&path);

    write_data(&path, &original);
    let loaded = read_data(&path, width, height);

    assert_eq!(loaded.len(), width * height);
    assert_eq!(loaded, original, "save/load changed the heights");
    let _ = std::fs::remove_file(&path);
}

fn sample_heights(width: usize, height: usize) -> Vec<f32> {
    let mut heights = Vec::with_capacity(width * height);
    for xi in 0..width {
        for zi in 0..height {
            // A varied range, incl. negatives and steep gradients the engine
            // would refuse — the file format stores them all losslessly.
            heights.push(xi as f32 * 1.5 - zi as f32 * 0.3 + 0.25);
        }
    }
    heights
}

fn write_data(path: &Path, heights: &[f32]) {
    match save_heightmap(path, heights) {
        HeightmapOutcome::Saved { .. } => {}
        other => panic!("save failed: {}", outcome_kind(&other)),
    }
}

fn read_data(path: &Path, width: usize, height: usize) -> Vec<f32> {
    match load_heightmap(path, width, height) {
        HeightmapOutcome::Loaded { heights, .. } => heights,
        other => panic!("load failed: {}", outcome_kind(&other)),
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
