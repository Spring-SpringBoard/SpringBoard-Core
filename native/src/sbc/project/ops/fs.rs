//! Filesystem write helpers that create parent directories and report failures
//! as human-readable strings.

use std::fs;
use std::path::Path;

pub(crate) fn write_bytes(path: &Path, bytes: &[u8]) -> Result<(), String> {
    if let Some(parent) = path.parent() {
        fs::create_dir_all(parent).map_err(|err| format!("create {}: {err}", parent.display()))?;
    }
    fs::write(path, bytes).map_err(|err| format!("write {}: {err}", path.display()))
}

pub(crate) fn copy_file(src: &Path, dest: &Path) -> Result<(), String> {
    if let Some(parent) = dest.parent() {
        fs::create_dir_all(parent).map_err(|err| format!("create {}: {err}", parent.display()))?;
    }
    fs::copy(src, dest)
        .map(|_| ())
        .map_err(|err| format!("copy {} -> {}: {err}", src.display(), dest.display()))
}
