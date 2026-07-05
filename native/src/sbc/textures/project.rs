use std::path::Path;

use log::{error, info};

use crate::sbc::command_system::context::Context;
use crate::sbc::project::io_registries::export::{MapExportOptions, MapExportRegistration};
use crate::sbc::project::io_registries::load::ProjectLoadRegistration;
use crate::sbc::project::io_registries::save::ProjectSaveRegistration;
use crate::sbc::project::model::paths::ProjectPaths;
use crate::sbc::textures::model::TextureModel;
use crate::sbc::textures::ops::{export, load, save};

const TEXTURES_DIR: &str = "textures";

inventory::submit! {
    ProjectSaveRegistration { save: save_textures }
}
inventory::submit! {
    ProjectLoadRegistration { load: load_textures }
}
inventory::submit! {
    MapExportRegistration { export: export_map_textures }
}

fn save_textures(ctx: &mut Context, paths: &ProjectPaths, is_new_project: bool) {
    let dir = paths.file(TEXTURES_DIR);
    let interface = *ctx.interface;
    let result = save::save(
        &interface,
        ctx.model::<TextureModel>(),
        &dir,
        is_new_project,
    );
    log_result("save textures", &dir, result);
}

fn load_textures(ctx: &mut Context, paths: &ProjectPaths) {
    let dir = paths.file(TEXTURES_DIR);
    if !has_png_files(&dir) {
        return;
    }
    let interface = *ctx.interface;
    let result = load::load(&interface, ctx.model::<TextureModel>(), &dir);
    log_result("load textures", &dir, result);
}

fn export_map_textures(ctx: &mut Context, output_dir: &Path, _options: &MapExportOptions) {
    let interface = *ctx.interface;
    let diffuse = output_dir.join("diffuse.png");
    let result = export::export_diffuse(&interface, ctx.model::<TextureModel>(), &diffuse);
    log_result("export diffuse", &diffuse, result);

    let result =
        export::export_shading_textures(&interface, ctx.model::<TextureModel>(), output_dir);
    log_result("export shading textures", output_dir, result);
}

fn has_png_files(path: &Path) -> bool {
    let Ok(entries) = std::fs::read_dir(path) else {
        return false;
    };
    entries.filter_map(Result::ok).any(|entry| {
        entry
            .path()
            .extension()
            .and_then(|ext| ext.to_str())
            .is_some_and(|ext| ext.eq_ignore_ascii_case("png"))
    })
}

fn log_result(op: &str, path: &Path, result: Result<(), String>) {
    match result {
        Ok(()) => info!("{op}: {}", path.display()),
        Err(err) => error!("{op} failed for {}: {err}", path.display()),
    }
}
