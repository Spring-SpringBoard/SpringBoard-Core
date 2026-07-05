use std::path::Path;

use crate::sbc::command_system::context::Context;
use crate::sbc::metal::jobs;
use crate::sbc::project::io_registries::export::{MapExportOptions, MapExportRegistration};
use crate::sbc::project::io_registries::load::ProjectLoadRegistration;
use crate::sbc::project::io_registries::save::ProjectSaveRegistration;
use crate::sbc::project::model::paths::ProjectPaths;

const METAL_FILE: &str = "metal.data";

inventory::submit! {
    ProjectSaveRegistration { save: save_project }
}

inventory::submit! {
    ProjectLoadRegistration { load: load_project }
}

inventory::submit! {
    MapExportRegistration { export: export_project }
}

fn save_project(ctx: &mut Context, paths: &ProjectPaths, _is_new_project: bool) {
    jobs::save::submit(ctx, paths.file(METAL_FILE));
}

fn load_project(ctx: &mut Context, paths: &ProjectPaths) {
    let path = paths.file(METAL_FILE);
    if path.is_file() {
        jobs::load::submit(ctx, path);
    }
}

fn export_project(ctx: &mut Context, output_dir: &Path, _options: &MapExportOptions) {
    jobs::export::submit(ctx, output_dir.join("metal.png"));
}
