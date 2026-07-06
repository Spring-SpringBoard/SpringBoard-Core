//! Copies a project's custom (user-added) files into an export tree, skipping
//! the editor-managed files (`sb_project_files/`, `.git`, `mapinfo.lua`).

use std::path::{Component, Path};

use super::fs::copy_file;
use crate::sbc::project::paths::PROJECT_FOLDER_PREFIX;

pub(crate) fn copy(src: &Path, dest: &Path) -> Result<(), String> {
    copy_dir(src, dest, src)
}

fn copy_dir(src_root: &Path, dest_root: &Path, dir: &Path) -> Result<(), String> {
    for entry in std::fs::read_dir(dir).map_err(|err| format!("read {}: {err}", dir.display()))? {
        let entry = entry.map_err(|err| format!("read entry in {}: {err}", dir.display()))?;
        let src_path = entry.path();
        let relative = src_path
            .strip_prefix(src_root)
            .map_err(|err| format!("strip {}: {err}", src_path.display()))?;
        if should_skip(relative) {
            continue;
        }

        let file_type = entry
            .file_type()
            .map_err(|err| format!("stat {}: {err}", src_path.display()))?;
        if file_type.is_dir() {
            copy_dir(src_root, dest_root, &src_path)?;
        } else if file_type.is_file() {
            log::info!("copying {}", src_path.display());
            copy_file(&src_path, &dest_root.join(relative))?;
        }
    }
    Ok(())
}

fn should_skip(relative: &Path) -> bool {
    if relative.components().next() == Some(Component::Normal(PROJECT_FOLDER_PREFIX.as_ref())) {
        return true;
    }
    relative
        .file_name()
        .and_then(|name| name.to_str())
        .is_some_and(|name| name == ".git" || name == "mapinfo.lua")
}
