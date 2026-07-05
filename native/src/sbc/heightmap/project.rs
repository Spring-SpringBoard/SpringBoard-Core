use std::path::Path;

use crate::sbc::command_system::context::Context;
use crate::sbc::heightmap::jobs;
use crate::sbc::project::io_registries::export::{MapExportOptions, MapExportRegistration};
use crate::sbc::project::io_registries::load::ProjectLoadRegistration;
use crate::sbc::project::io_registries::save::ProjectSaveRegistration;
use crate::sbc::project::model::paths::ProjectPaths;

const HEIGHTMAP_FILE: &str = "heightmap.data";

inventory::submit! {
    ProjectSaveRegistration { save }
}
inventory::submit! {
    ProjectLoadRegistration { load }
}
inventory::submit! {
    MapExportRegistration { export }
}

fn save(ctx: &mut Context, paths: &ProjectPaths, _is_new_project: bool) {
    jobs::save::submit(ctx, paths.file(HEIGHTMAP_FILE));
}

fn load(ctx: &mut Context, paths: &ProjectPaths) {
    let path = paths.file(HEIGHTMAP_FILE);
    if path.is_file() {
        jobs::load::submit(ctx, path);
    }
}

fn export(ctx: &mut Context, output_dir: &Path, options: &MapExportOptions) {
    jobs::export::submit(
        ctx,
        output_dir.join("heightmap.png"),
        options.heightmap_extremes.clone(),
    );
}
