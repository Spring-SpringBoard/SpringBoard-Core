//! Assembles a Spring `.sdz` archive: writes the model/assets tree, compiles the
//! map, folds in shading exports, and zips it up.

use std::fs;
use std::path::{Path, PathBuf};

use super::fs::{copy_file, write_bytes};
use super::{archive, custom_files};
use crate::sbc::compile::{self, CompileMapOpts};

pub(crate) struct ArchiveAsset {
    pub path: PathBuf,
    pub bytes: Vec<u8>,
}

pub(crate) struct Spec {
    pub build_dir: PathBuf,
    pub archive_dir: PathBuf,
    pub maps_dir: PathBuf,
    pub project_path: PathBuf,
    pub project_name: String,
    pub output_path: PathBuf,
    pub compiler_path: PathBuf,
    pub map_info: String,
    pub s11n_model: String,
    pub assets: Vec<ArchiveAsset>,
}

pub(crate) fn build(spec: Spec) -> Result<(), String> {
    fs::create_dir_all(&spec.archive_dir)
        .map_err(|err| format!("create {}: {err}", spec.archive_dir.display()))?;
    fs::create_dir_all(&spec.maps_dir)
        .map_err(|err| format!("create {}: {err}", spec.maps_dir.display()))?;

    for asset in &spec.assets {
        write_bytes(&spec.archive_dir.join(&asset.path), &asset.bytes)?;
    }
    write_bytes(&spec.archive_dir.join("mapinfo.lua"), spec.map_info.as_bytes())?;
    write_bytes(
        &spec.archive_dir.join("mapconfig").join("s11n_model.lua"),
        spec.s11n_model.as_bytes(),
    )?;
    if spec.project_path.exists() {
        custom_files::copy(&spec.project_path, &spec.archive_dir)?;
    }

    compile::ops::run(&compile_opts(&spec), &spec.compiler_path)?;

    copy_if_exists(
        &spec.build_dir.join("grass.png"),
        &spec.maps_dir.join("grass.png"),
    )?;
    copy_shading_exports(&spec.build_dir, &spec.maps_dir)?;
    archive::export(&spec.archive_dir, &spec.output_path)?;
    remove_dir_all(&spec.build_dir)
}

fn compile_opts(spec: &Spec) -> CompileMapOpts {
    let build = |name: &str| spec.build_dir.join(name).to_string_lossy().into_owned();
    CompileMapOpts {
        height_path: build("heightmap.png"),
        diffuse_path: build("diffuse.png"),
        metal_path: Some(build("metal.png")),
        type_path: None,
        output_path: spec
            .maps_dir
            .join(&spec.project_name)
            .to_string_lossy()
            .into_owned(),
        write_path: String::new(),
        minimap: Some(build("diffuse.png")),
        maxh: None,
        minh: None,
    }
}

fn copy_shading_exports(build_dir: &Path, maps_dir: &Path) -> Result<(), String> {
    for entry in
        fs::read_dir(build_dir).map_err(|err| format!("read {}: {err}", build_dir.display()))?
    {
        let entry = entry.map_err(|err| format!("read entry in {}: {err}", build_dir.display()))?;
        let path = entry.path();
        if !path.is_file() {
            continue;
        }
        let Some(file_name) = path.file_name().and_then(|name| name.to_str()) else {
            continue;
        };
        if !file_name.ends_with(".png")
            || matches!(
                file_name,
                "heightmap.png" | "diffuse.png" | "metal.png" | "grass.png"
            )
        {
            continue;
        }
        copy_file(&path, &maps_dir.join(file_name))?;
    }
    Ok(())
}

fn copy_if_exists(src: &Path, dest: &Path) -> Result<(), String> {
    if src.exists() {
        copy_file(src, dest)?;
    }
    Ok(())
}

fn remove_dir_all(path: &Path) -> Result<(), String> {
    match fs::remove_dir_all(path) {
        Ok(()) => Ok(()),
        Err(err) if err.kind() == std::io::ErrorKind::NotFound => Ok(()),
        Err(err) => Err(format!("remove {}: {err}", path.display())),
    }
}
