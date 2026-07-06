use std::time::Duration;

use crate::sbc::tests::tests_api::TestCtx;

/// Exports the booted map's heightmap + diffuse, then drives `CompileMapCommand`
/// through the bundled `mapcompile` and asserts a real `.smf`/`.smt` pair lands.
///
/// Opt-in: a full-map compile takes ~1-2 min, so this is skipped by the default
/// suite. It runs under `just test-all` (deep) or when its tag is explicitly
/// requested (`just test-integration compile_map`).
fn compile_map_produces_smf(ctx: &mut TestCtx) -> Result<(), String> {
    let root = std::env::temp_dir().join("sbc_compile_map.sdd");
    let export_dir = root.join("exports");
    let height_png = export_dir.join("heightmap.png");
    let diffuse_png = export_dir.join("diffuse.png");
    let output_suffix = root.join("Compiled");
    let output_smf = root.join("Compiled.smf");
    let output_smt = root.join("Compiled.smt");
    let _ = std::fs::remove_dir_all(&root);

    // Compiler inputs come from the real export path, so their dimensions are
    // valid for mapcompile by construction.
    ctx.route_command(serde_json::json!({
        "className": "ExportMapsCommand",
        "path": export_dir.to_string_lossy(),
    }));
    if !ctx.wait_for_file(&height_png, Duration::from_secs(15)) {
        return Err("ExportMapsCommand did not write heightmap.png".to_string());
    }
    if !ctx.wait_for_file(&diffuse_png, Duration::from_secs(15)) {
        return Err("ExportMapsCommand did not write diffuse.png".to_string());
    }

    ctx.route_command(serde_json::json!({
        "className": "CompileMapCommand",
        "heightPath": height_png.to_string_lossy(),
        "diffusePath": diffuse_png.to_string_lossy(),
        "outputPath": output_suffix.to_string_lossy(),
    }));
    if !ctx.wait_for_file(&output_smf, Duration::from_secs(180)) {
        return Err("CompileMapCommand did not produce Compiled.smf".to_string());
    }

    let smf_size = std::fs::metadata(&output_smf)
        .map_err(|e| format!("stat Compiled.smf: {e}"))?
        .len();
    if smf_size < 1024 {
        return Err(format!(
            "Compiled.smf is implausibly small: {smf_size} bytes"
        ));
    }
    if !output_smt.is_file() {
        return Err("CompileMapCommand did not produce Compiled.smt".to_string());
    }

    let _ = std::fs::remove_dir_all(&root);
    Ok(())
}

crate::integration_test!(
    "compile_map_produces_smf",
    compile_map_produces_smf,
    opt_in = true
);
