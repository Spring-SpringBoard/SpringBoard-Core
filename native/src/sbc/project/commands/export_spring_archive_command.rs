use std::path::{Path, PathBuf};

use serde::Deserialize;

use crate::sbc::command_system::command::Command;
use crate::sbc::command_system::context::Context;
use crate::sbc::command_system::io_completion;
use crate::sbc::command_system::registry::register_command;
use crate::sbc::compile::ops::compiler_path;
use crate::sbc::notifications::NotificationManager;
use crate::sbc::project::io_registries::export::{self, MapExportOptions};
use crate::sbc::project::jobs::archive_export::ExportSpringArchiveJob;
use crate::sbc::project::ops::{archive_assets, lua_writer, map_info, model_codec};
use crate::sbc::project::{ProjectManager, ScenarioInfoManager};

#[derive(Deserialize, Debug)]
pub struct ExportSpringArchiveCommand {
    path: String,
    #[serde(default, rename = "heightmapExtremes")]
    heightmap_extremes: Option<Vec<f32>>,
    #[serde(default, rename = "projectPath")]
    project_path: Option<String>,
    #[serde(default, rename = "projectName")]
    project_name: Option<String>,
    #[serde(default, rename = "writePath")]
    write_path: Option<String>,
}

impl ExportSpringArchiveCommand {
    pub(crate) fn new(path: String) -> Self {
        Self {
            path,
            heightmap_extremes: None,
            project_path: None,
            project_name: None,
            write_path: None,
        }
    }
}

impl Command for ExportSpringArchiveCommand {
    fn execute(&mut self, ctx: &mut Context) {
        let Some(project_path) = self.project_path(ctx) else {
            log::error!("ExportSpringArchiveCommand: missing project path");
            ctx.model::<NotificationManager>()
                .warn("export", "The project must be saved before exporting");
            io_completion::submit_native_command_completed(ctx);
            return;
        };
        let project_path = path_under_write(self.write_path.as_deref(), &project_path);
        let project_name = self.project_name(ctx);
        ctx.model::<NotificationManager>()
            .progress("export", 0.1, "Exporting archive...");
        self.warn_if_map_name_taken(ctx);
        let build_dir = std::env::temp_dir().join(format!(
            "sbc-export-{}-{}",
            std::process::id(),
            ctx.current_command_id
        ));
        let archive_dir = build_dir.join("archive");
        let maps_dir = archive_dir.join("maps");
        let output_path = path_under_write(self.write_path.as_deref(), &archive_path(&self.path));

        export::export_maps(
            ctx,
            &build_dir,
            &MapExportOptions {
                heightmap_extremes: self.heightmap_extremes.clone(),
            },
        );

        let compiler_path = match compiler_path(ctx) {
            Ok(path) => path,
            Err(reason) => {
                log::error!("ExportSpringArchiveCommand: {reason}");
                io_completion::submit_native_command_completed(ctx);
                return;
            }
        };
        let assets = match archive_assets::gather(ctx) {
            Ok(assets) => assets,
            Err(reason) => {
                log::error!("ExportSpringArchiveCommand: {reason}");
                io_completion::submit_native_command_completed(ctx);
                return;
            }
        };
        let map_info = map_info::export_text(ctx);
        let s11n_model = lua_writer::table_file(&model_codec::serialize_model_ctx(ctx));

        ctx.submit_io(Box::new(ExportSpringArchiveJob {
            build_dir,
            archive_dir,
            maps_dir,
            project_path,
            project_name,
            output_path,
            compiler_path,
            map_info,
            s11n_model,
            assets,
        }));
        io_completion::submit_native_command_completed(ctx);
    }

    fn undoable(&self) -> bool {
        false
    }
}

impl ExportSpringArchiveCommand {
    /// Warn if the exported map's name is already taken by another archive. The
    /// engine resolves maps by name, so a duplicate would be shadowed and the
    /// export could not be opened in New Project — the fix is to rename it in
    /// Misc → Info before exporting.
    fn warn_if_map_name_taken(&self, ctx: &mut Context) {
        let info = ctx.model::<ScenarioInfoManager>().serialize().clone();
        let name = info.name.trim().to_string();
        if name.is_empty() {
            return;
        }
        let map_name = if info.version.trim().is_empty() {
            name.clone()
        } else {
            format!("{name} {}", info.version.trim())
        };
        let name_prefix = format!("{name} ");
        let taken = ctx
            .interface
            .vfs()
            .get_maps()
            .unwrap_or_default()
            .into_iter()
            .any(|existing| existing == map_name || existing.starts_with(&name_prefix));
        if taken {
            ctx.model::<NotificationManager>().warn(
                "export-collision",
                &format!(
                    "A map named \"{map_name}\" already exists — the exported map may be unreachable. Rename it in Misc → Info before exporting."
                ),
            );
        }
    }

    fn project_path(&self, ctx: &mut Context) -> Option<PathBuf> {
        if let Some(path) = self.project_path.as_deref() {
            return Some(PathBuf::from(path));
        }
        ctx.model::<ProjectManager>().path().map(PathBuf::from)
    }

    fn project_name(&self, ctx: &mut Context) -> String {
        if let Some(name) = self.project_name.as_deref().filter(|n| !n.is_empty()) {
            return name.to_string();
        }
        let name = ctx.model::<ProjectManager>().name().unwrap_or("");
        if name.is_empty() {
            "springboard_map".to_string()
        } else {
            name.to_string()
        }
    }
}

fn archive_path(path: &str) -> PathBuf {
    let mut out = PathBuf::from(path);
    if out.extension().and_then(|ext| ext.to_str()) != Some("sdz") {
        out.set_extension("sdz");
    }
    out
}

fn path_under_write(write_path: Option<&str>, path: &Path) -> PathBuf {
    if path.is_absolute() {
        return path.to_path_buf();
    }
    match write_path.filter(|path| !path.is_empty()) {
        Some(write_path) => Path::new(write_path).join(path),
        None => path.to_path_buf(),
    }
}

register_command!(ExportSpringArchiveCommand, "ExportSpringArchiveCommand");
