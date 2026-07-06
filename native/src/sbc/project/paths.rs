use std::path::{Path, PathBuf};

pub(crate) const PROJECT_FOLDER_PREFIX: &str = "sb_project_files";

/// Resolves per-feature file paths inside a project. Handed to save/load
/// registrations so features name their file (`"heightmap.data"`) without
/// knowing the on-disk folder layout.
pub(crate) struct ProjectPaths {
    files_dir: PathBuf,
}

impl ProjectPaths {
    pub(crate) fn new(project_path: &Path) -> Self {
        ProjectPaths {
            files_dir: project_path.join(PROJECT_FOLDER_PREFIX),
        }
    }

    /// Full path to `name` within the project's files directory.
    pub(crate) fn file(&self, name: &str) -> PathBuf {
        self.files_dir.join(name)
    }
}
