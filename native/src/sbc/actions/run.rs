//! Running an [`Action`]: `execute` returns what the manager should do next
//! (dispatch commands, open a dialog), and `can_execute` gates the ones that
//! need a selection or a clipboard.
//!
//! Actions that need user input (file paths, project names) return an
//! [`ActionResult::OpenFileDialog`] or [`ActionResult::OpenNewProject`]; the
//! manager opens the dialog and calls back with the result, so this layer stays
//! free of RmlUi / DOM concerns.

use spring_native::prelude::NativeInterfaceRef;

use super::action::Action;
use super::clipboard::Clipboard;
use super::dialog::{ActionResult, FileDialogConfig};
use super::helpers::{game_id, ground_extremes};
use super::paths::{EXPORTS_DIR, PROJECTS_DIR};
use crate::sbc::command_system::command::{Command, CompoundCommand};
use crate::sbc::command_system::model::Models;
use crate::sbc::command_system::{RedoCommand, UndoCommand};
use crate::sbc::heightmap::commands::{ExportHeightmapCommand, ImportHeightmapCommand};
use crate::sbc::objects::{ObjectKind, ObjectManager, RemoveObjectCommand, SelectionManager};
use crate::sbc::project::commands::{
    ExportMapInfoCommand, ExportMapsCommand, ExportS11NCommand, ExportSpringArchiveCommand,
    ReloadIntoProjectCommand, SaveCommand, SaveProjectInfoCommand, SetProjectNamePathCommand,
};
use crate::sbc::project::model::project_manager::ProjectManager;
use crate::sbc::textures::commands::ImportDiffuseCommand;

/// Whether an action can run right now. Toolbar buttons could grey out; hotkeys
/// silently no-op when this returns false.
pub fn can_execute(action: Action, models: &mut Models) -> bool {
    match action {
        Action::Copy | Action::Cut | Action::Delete => models.get::<SelectionManager>().count() > 0,
        Action::Paste => !models.get::<Clipboard>().is_empty(),
        // Undo/Redo always allowed (the command system no-ops on empty history);
        // project ops require dev mode, which the native UI always is.
        _ => true,
    }
}

/// Execute an action. Returns what the manager should do next.
pub fn execute(
    action: Action,
    _interface: &NativeInterfaceRef,
    models: &mut Models,
) -> ActionResult {
    match action {
        Action::Undo => ActionResult::NativeCommands(vec![Box::new(UndoCommand)]),
        Action::Redo => ActionResult::NativeCommands(vec![Box::new(RedoCommand)]),

        Action::Save => {
            let pm = models.get::<ProjectManager>();
            if pm.path().is_some() {
                ActionResult::NativeCommands(save_commands(pm))
            } else {
                // No path known — fall through to Save As.
                open_save_as()
            }
        }

        Action::SaveAs => open_save_as(),

        Action::Load => {
            let config = FileDialogConfig {
                title: "Open project".to_string(),
                root_dir: PROJECTS_DIR.to_string(),
                dirs_as_items: true,
                extensions: vec![".sdd".to_string()],
                ..Default::default()
            };
            ActionResult::OpenFileDialog {
                config,
                on_accept: Box::new(|result, interface| {
                    let (game_name, game_version) = game_id(interface);
                    vec![Box::new(ReloadIntoProjectCommand::new(
                        result.path.clone(),
                        game_name,
                        game_version,
                    ))]
                }),
            }
        }

        Action::Import => {
            let config = FileDialogConfig {
                title: "Import".to_string(),
                root_dir: PROJECTS_DIR.to_string(),
                extensions: [".png", ".jpg", ".bmp", ".tga", ".tif"]
                    .iter()
                    .map(|s| s.to_string())
                    .collect(),
                file_types: vec!["Diffuse".to_string(), "Heightmap".to_string()],
                ..Default::default()
            };
            ActionResult::OpenFileDialog {
                config,
                on_accept: Box::new(|result, interface| {
                    match result.file_type.as_deref() {
                        // A follow-up could open a sub-dialog for custom
                        // min/max; for now use the engine's ground extremes.
                        Some("Heightmap") => {
                            let (min_h, max_h) = ground_extremes(interface);
                            vec![Box::new(ImportHeightmapCommand::new(
                                result.path.clone(),
                                min_h,
                                max_h,
                            ))]
                        }
                        _ => vec![Box::new(ImportDiffuseCommand::new(result.path.clone()))],
                    }
                }),
            }
        }

        Action::Export => {
            let config = FileDialogConfig {
                title: "Export".to_string(),
                root_dir: EXPORTS_DIR.to_string(),
                file_types: [
                    "Spring archive",
                    "Map textures",
                    "Heightmap (16-bit PNG)",
                    "Map info",
                    "s11n object format",
                ]
                .iter()
                .map(|s| s.to_string())
                .collect(),
                show_name_input: true,
                ..Default::default()
            };
            ActionResult::OpenFileDialog {
                config,
                on_accept: Box::new(|result, _interface| {
                    let path = &result.path;
                    let cmd: Box<dyn Command> = match result.file_type.as_deref().unwrap_or("") {
                        "Spring archive" => Box::new(ExportSpringArchiveCommand::new(path.clone())),
                        "Map textures" => Box::new(ExportMapsCommand::new(path.clone())),
                        "Heightmap (16-bit PNG)" => {
                            Box::new(ExportHeightmapCommand::new(path.clone()))
                        }
                        "Map info" => Box::new(ExportMapInfoCommand::new(format!("{path}.lua"))),
                        "s11n object format" => {
                            Box::new(ExportS11NCommand::new(format!("{path}.lua")))
                        }
                        _ => return vec![],
                    };
                    vec![cmd]
                }),
            }
        }

        Action::NewProject => ActionResult::OpenNewProject,

        // ── Selection / clipboard ──
        Action::Delete => remove_selected(models),

        Action::Copy => {
            let items = copy_selection(models);
            models.get::<Clipboard>().copy(&items);
            ActionResult::None
        }

        Action::Cut => {
            let items = copy_selection(models);
            models.get::<Clipboard>().copy(&items);
            remove_selected(models)
        }

        // Paste needs the cursor's ground hit, so the manager runs it directly.
        Action::Paste => ActionResult::None,

        Action::SelectAll => {
            select_all(models);
            ActionResult::None
        }
        Action::SelectSameType => {
            select_same_type(models);
            ActionResult::None
        }
        Action::SelectSameTypeInView => {
            select_same_type(models);
            ActionResult::None
        }
    }
}

/// Paste the clipboard with a known ground position (from the cursor ray).
pub fn execute_paste(
    interface: &NativeInterfaceRef,
    models: &mut Models,
    ground_x: f32,
    ground_z: f32,
) -> Vec<Box<dyn Command>> {
    let cb = models.get::<Clipboard>();
    if cb.is_empty() {
        return vec![];
    }
    let commands = cb.paste_commands(interface, ground_x, ground_z);
    if commands.is_empty() {
        return vec![];
    }
    vec![Box::new(CompoundCommand { commands })]
}

// ── Command builders ─────────────────────────────────────────────

fn open_save_as() -> ActionResult {
    let config = FileDialogConfig {
        title: "Save project as...".to_string(),
        root_dir: PROJECTS_DIR.to_string(),
        show_name_input: true,
        dirs_as_items: true,
        extensions: vec![".sdd".to_string()],
        ..Default::default()
    };
    ActionResult::OpenFileDialog {
        config,
        on_accept: Box::new(|result, iface| {
            let name = result
                .path
                .strip_prefix(PROJECTS_DIR)
                .unwrap_or(&result.path)
                .trim_end_matches(".sdd")
                .to_string();
            let path = result.path.clone();
            let (game_name, game_version) = game_id(iface);
            // Saving under a new name is a new project: reload into it, as Lua's
            // Project:Save does for isNewProject. The save writes script.txt
            // asynchronously, so the reload builds from the in-memory project.
            vec![
                Box::new(SetProjectNamePathCommand::new(name.clone(), path.clone())),
                Box::new(SaveProjectInfoCommand::new(name, path.clone(), true, None)),
                Box::new(SaveCommand::new(path.clone(), true)),
                Box::new(ReloadIntoProjectCommand::after_save(
                    path,
                    game_name,
                    game_version,
                )),
            ]
        }),
    }
}

fn save_commands(pm: &ProjectManager) -> Vec<Box<dyn Command>> {
    let path = pm.path().unwrap_or_default().to_string();
    let name = pm.name().unwrap_or_default().to_string();
    vec![
        Box::new(SaveProjectInfoCommand::new(name, path.clone(), false, None)),
        Box::new(SaveCommand::new(path, false)),
    ]
}

// ── Selection ────────────────────────────────────────────────────

/// Remove the current selection as one undo group.
fn remove_selected(models: &mut Models) -> ActionResult {
    let selection = models.get::<SelectionManager>().all();
    let commands: Vec<Box<dyn Command>> = selection
        .into_iter()
        .map(|(kind, model_id)| {
            Box::new(RemoveObjectCommand::new(kind, model_id)) as Box<dyn Command>
        })
        .collect();
    if commands.is_empty() {
        ActionResult::None
    } else {
        ActionResult::NativeCommands(vec![Box::new(CompoundCommand { commands })])
    }
}

fn copy_selection(models: &mut Models) -> Vec<(ObjectKind, serde_json::Value)> {
    let selection = models.get::<SelectionManager>().all();
    let objects = models.get::<ObjectManager>();
    selection
        .iter()
        .filter_map(|(kind, id)| objects.object_json(*kind, *id).map(|json| (*kind, json)))
        .collect()
}

fn select_all(models: &mut Models) {
    let objects = models.get::<ObjectManager>();
    let mut selection = Vec::new();
    for kind in [ObjectKind::Unit, ObjectKind::Feature] {
        for id in objects.all_model_ids(kind) {
            selection.push((kind, id));
        }
    }
    models.get::<SelectionManager>().set_selection(selection);
}

fn select_same_type(models: &mut Models) {
    let current = models.get::<SelectionManager>().all();
    let objects = models.get::<ObjectManager>();

    let mut def_names: std::collections::HashSet<String> = std::collections::HashSet::new();
    for (kind, model_id) in &current {
        if let Some(def) = objects.def_name(*kind, *model_id) {
            def_names.insert(def);
        }
    }

    let mut selection = Vec::new();
    for kind in [ObjectKind::Unit, ObjectKind::Feature] {
        for id in objects.all_model_ids(kind) {
            if objects
                .def_name(kind, id)
                .is_some_and(|d| def_names.contains(&d))
            {
                selection.push((kind, id));
            }
        }
    }
    models.get::<SelectionManager>().set_selection(selection);
}
