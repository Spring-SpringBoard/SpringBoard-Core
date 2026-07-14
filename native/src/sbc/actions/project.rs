//! Creating a new project: turning the New Project dialog's fields into the
//! `SaveProjectInfoCommand` + `ReloadIntoProjectCommand` pair, and enumerating
//! the maps the dialog offers.

use spring_native::prelude::NativeInterfaceRef;

use super::helpers::{game_id, rand_u32};
use super::paths::PROJECTS_DIR;
use crate::sbc::command_system::command::Command;
use crate::sbc::project::commands::{ReloadIntoProjectCommand, SaveProjectInfoCommand};
use crate::sbc::project::ProjectData;

/// The blank map's archive name; its size comes from `randomMapOptions`.
const BLANK_MAP: &str = "SB_Blank_Map";

/// Build the commands for creating a new project, called by the manager after
/// the NewProject dialog completes.
pub fn commit_new_project(
    name: &str,
    map_name: &str,
    size_x: Option<f32>,
    size_y: Option<f32>,
    interface: &NativeInterfaceRef,
) -> Vec<Box<dyn Command>> {
    let project_name = name.trim().trim_end_matches(".sdd");
    let path = format!("{PROJECTS_DIR}{project_name}.sdd");
    let (game_name, game_version) = game_id(interface);

    // For the blank map, the size is carried in randomMapOptions and the engine
    // generates a fresh map; a seed keeps the archive out of a stale cache.
    let random_map_options = if map_name == BLANK_MAP {
        Some(serde_json::json!({
            "mapSeed": rand_u32(),
            "new_map_x": size_x.unwrap_or(10.0),
            "new_map_y": size_y.unwrap_or(10.0),
        }))
    } else {
        None
    };

    // The full project record, so the chosen map and target game are saved into
    // the start script the reload reads back.
    let project = ProjectData {
        name: Some(project_name.to_string()),
        path: Some(path.clone()),
        map_name: Some(map_name.to_string()),
        game: Some(serde_json::json!({ "name": game_name, "version": game_version })),
        random_map_options,
        mutators: vec![format!("{project_name} 1.0")],
    };

    vec![
        Box::new(SaveProjectInfoCommand::new(
            project_name.to_string(),
            path.clone(),
            true,
            Some(project),
        )),
        Box::new(ReloadIntoProjectCommand::new(path, game_name, game_version)),
    ]
}

/// Maps the VFS has an archive for, for the New Project dialog dropdown.
pub fn available_maps(interface: &NativeInterfaceRef) -> Vec<String> {
    let vfs = interface.vfs();
    let mut maps = vfs.get_maps().unwrap_or_default();
    maps.sort();
    maps.into_iter()
        .filter(|m| vfs.has_archive(m).unwrap_or(false))
        .collect()
}
