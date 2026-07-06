//! Resolves an on-disk, ready-to-exec path to the bundled `mapcompile` binary.

use std::path::{Path, PathBuf};

use crate::sbc::command_system::context::Context;

#[cfg(target_os = "windows")]
const COMPILER_VFS_PATH: &str = "dist_cfg/bin/windows/springMapConvNG.exe";
#[cfg(not(target_os = "windows"))]
const COMPILER_VFS_PATH: &str = "dist_cfg/bin/linux/mapcompile";

#[cfg(target_os = "windows")]
const EXECUTABLE_SUFFIX: &str = ".exe";
#[cfg(not(target_os = "windows"))]
const EXECUTABLE_SUFFIX: &str = "";

/// A ready-to-exec path to the bundled `mapcompile` binary. When SBC runs from a
/// directory (`.sdd`) the file is on disk and we exec it in place; when it lives
/// inside a zipped/rapid archive we extract it to a temp file first.
pub(crate) fn compiler_path(ctx: &Context) -> Result<PathBuf, String> {
    let vfs = ctx.interface.vfs();
    match vfs.get_file_absolute_path(COMPILER_VFS_PATH, "r") {
        Ok(Some(path)) => return Ok(PathBuf::from(path)),
        Ok(None) => {}
        Err(err) => return Err(format!("resolving compiler {COMPILER_VFS_PATH}: {err:?}")),
    }
    let bytes = vfs
        .read_file(COMPILER_VFS_PATH)
        .map_err(|err| format!("missing bundled compiler {COMPILER_VFS_PATH}: {err:?}"))?;
    extract_executable(&bytes)
}

fn extract_executable(bytes: &[u8]) -> Result<PathBuf, String> {
    let path = std::env::temp_dir().join(format!(
        "sbc-mapcompile-{}{EXECUTABLE_SUFFIX}",
        std::process::id()
    ));
    std::fs::write(&path, bytes).map_err(|err| format!("write {}: {err}", path.display()))?;
    make_executable(&path)?;
    Ok(path)
}

#[cfg(unix)]
fn make_executable(path: &Path) -> Result<(), String> {
    use std::os::unix::fs::PermissionsExt;

    let mut perms = std::fs::metadata(path)
        .map_err(|err| format!("stat {}: {err}", path.display()))?
        .permissions();
    perms.set_mode(0o755);
    std::fs::set_permissions(path, perms).map_err(|err| format!("chmod {}: {err}", path.display()))
}

#[cfg(not(unix))]
fn make_executable(_path: &Path) -> Result<(), String> {
    Ok(())
}
