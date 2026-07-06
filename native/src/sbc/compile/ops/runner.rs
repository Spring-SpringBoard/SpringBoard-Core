//! Runs the bundled `mapcompile` binary to produce a `.smf`/`.smt` map from the
//! exported height/diffuse/metal/type images.

use std::path::{Path, PathBuf};
use std::process::{Command as ProcessCommand, Stdio};

use log::{debug, info};

use crate::sbc::compile::CompileMapOpts;

pub(crate) fn run(opts: &CompileMapOpts, compiler_path: &Path) -> Result<PathBuf, String> {
    let write_path = PathBuf::from(&opts.write_path);
    let output_path = absolute_under_write(&write_path, &opts.output_path);
    let mut args = vec![
        "-t".to_string(),
        absolute_under_write(&write_path, &opts.diffuse_path)
            .to_string_lossy()
            .into_owned(),
        "-h".to_string(),
        absolute_under_write(&write_path, &opts.height_path)
            .to_string_lossy()
            .into_owned(),
        "-ct".to_string(),
        "1".to_string(),
        "-o".to_string(),
        output_path.to_string_lossy().into_owned(),
    ];
    if let Some(path) = &opts.metal_path {
        args.push("-m".to_string());
        args.push(
            absolute_under_write(&write_path, path)
                .to_string_lossy()
                .into_owned(),
        );
    }
    if let Some(path) = &opts.type_path {
        args.push("-z".to_string());
        args.push(
            absolute_under_write(&write_path, path)
                .to_string_lossy()
                .into_owned(),
        );
    }
    if let Some(maxh) = &opts.maxh {
        args.push("-maxh".to_string());
        args.push(maxh.clone());
    }
    if let Some(minh) = &opts.minh {
        args.push("-minh".to_string());
        args.push(minh.clone());
    }
    if let Some(minimap) = &opts.minimap {
        args.push("-minimap".to_string());
        args.push(
            absolute_under_write(&write_path, minimap)
                .to_string_lossy()
                .into_owned(),
        );
    }

    info!("mapcompile {}", args.join(" "));
    let output = ProcessCommand::new(compiler_path)
        .args(&args)
        .stdin(Stdio::null())
        .output()
        .map_err(|err| format!("spawn {}: {err}", compiler_path.display()))?;
    if !output.status.success() {
        let stdout = String::from_utf8_lossy(&output.stdout);
        let stderr = String::from_utf8_lossy(&output.stderr);
        return Err(format!(
            "{} exited with {}.\nstdout:\n{}\nstderr:\n{}",
            compiler_path.display(),
            output.status,
            stdout,
            stderr
        ));
    }
    let stdout = String::from_utf8_lossy(&output.stdout);
    if !stdout.trim().is_empty() {
        debug!("mapcompile stdout:\n{stdout}");
    }
    Ok(output_path)
}

fn absolute_under_write(write_path: &Path, path: &str) -> PathBuf {
    let path = PathBuf::from(path);
    if path.is_absolute() || write_path.as_os_str().is_empty() {
        path
    } else {
        write_path.join(path)
    }
}
