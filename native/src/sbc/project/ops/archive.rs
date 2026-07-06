//! Zips a prepared archive directory into a Spring `.sdz` archive.

use std::path::{Path, PathBuf};

pub(crate) fn export(archive_dir: &Path, path: &Path) -> Result<(), String> {
    if !archive_dir.is_dir() {
        return Err(format!(
            "archive dir does not exist: {}",
            archive_dir.display()
        ));
    }
    if let Some(parent) = path.parent() {
        std::fs::create_dir_all(parent)
            .map_err(|err| format!("create {}: {err}", parent.display()))?;
    }
    if path.exists() {
        std::fs::remove_file(path).map_err(|err| format!("remove {}: {err}", path.display()))?;
    }

    let output = absolute_path(path)?;
    let status = std::process::Command::new("zip")
        .arg("-qr")
        .arg(&output)
        .arg(".")
        .current_dir(archive_dir)
        .status()
        .map_err(|err| format!("run zip: {err}"))?;
    if !status.success() {
        return Err(format!("zip exited with {status}"));
    }
    Ok(())
}

fn absolute_path(path: &Path) -> Result<PathBuf, String> {
    if path.is_absolute() {
        return Ok(path.to_path_buf());
    }
    std::env::current_dir()
        .map(|cwd| cwd.join(path))
        .map_err(|err| format!("read current dir: {err}"))
}
