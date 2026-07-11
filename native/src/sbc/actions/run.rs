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
use crate::sbc::command_system::model::Models;
use crate::sbc::envelope::envelope_fields;
use crate::sbc::objects::{ObjectKind, ObjectManager, SelectionManager};
use crate::sbc::project::model::project_manager::ProjectManager;

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
    next: &mut u64,
) -> ActionResult {
    match action {
        Action::Undo => simple_command("UndoCommand", next),
        Action::Redo => simple_command("RedoCommand", next),

        Action::Save => {
            let pm = models.get::<ProjectManager>();
            if pm.path().is_some() {
                ActionResult::Commands(save_envelopes(pm, next))
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
                on_accept: Box::new(|result, interface, next| {
                    let (game_name, game_version) = game_id(interface);
                    vec![envelope_fields(
                        "ReloadIntoProjectCommand",
                        next,
                        serde_json::json!({
                            "path": result.path,
                            "modOptions": serde_json::json!({}),
                            "gameName": game_name,
                            "gameVersion": game_version,
                        }),
                    )]
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
                on_accept: Box::new(|result, interface, next| {
                    let cmd = match result.file_type.as_deref() {
                        Some("Heightmap") => {
                            // A follow-up could open a sub-dialog for custom
                            // min/max; for now use the engine's ground extremes.
                            let (min_h, max_h) = ground_extremes(interface);
                            envelope_fields(
                                "ImportHeightmapCommand",
                                next,
                                serde_json::json!({
                                    "heightmapImage": result.path,
                                    "minHeight": min_h,
                                    "maxHeight": max_h,
                                }),
                            )
                        }
                        _ => envelope_fields(
                            "ImportDiffuseCommand",
                            next,
                            serde_json::json!({ "texturePath": result.path }),
                        ),
                    };
                    vec![cmd]
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
                on_accept: Box::new(|result, _interface, next| {
                    let path = &result.path;
                    let cmd = match result.file_type.as_deref().unwrap_or("") {
                        "Spring archive" => envelope_fields(
                            "ExportSpringArchiveCommand",
                            next,
                            serde_json::json!({ "path": path }),
                        ),
                        "Map textures" => envelope_fields(
                            "ExportMapsCommand",
                            next,
                            serde_json::json!({ "path": path }),
                        ),
                        "Heightmap (16-bit PNG)" => envelope_fields(
                            "ExportHeightmapCommand",
                            next,
                            serde_json::json!({ "path": path }),
                        ),
                        "Map info" => envelope_fields(
                            "ExportMapInfoCommand",
                            next,
                            serde_json::json!({ "path": format!("{path}.lua") }),
                        ),
                        "s11n object format" => envelope_fields(
                            "ExportS11NCommand",
                            next,
                            serde_json::json!({ "path": format!("{path}.lua") }),
                        ),
                        _ => return vec![],
                    };
                    vec![cmd]
                }),
            }
        }

        Action::NewProject => ActionResult::OpenNewProject,

        // ── Selection / clipboard ──
        Action::Delete => remove_selected(models, next),

        Action::Copy => {
            let items = copy_selection(models);
            models.get::<Clipboard>().copy(&items);
            ActionResult::None
        }

        Action::Cut => {
            let items = copy_selection(models);
            models.get::<Clipboard>().copy(&items);
            remove_selected(models, next)
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
    next: &mut u64,
) -> Vec<String> {
    let cb = models.get::<Clipboard>();
    if cb.is_empty() {
        return vec![];
    }
    let envelopes = cb.paste_envelopes(interface, ground_x, ground_z, next);
    if envelopes.is_empty() {
        return vec![];
    }
    vec![compound(envelopes, next)]
}

// ── Command builders ─────────────────────────────────────────────

fn simple_command(class: &str, next: &mut u64) -> ActionResult {
    ActionResult::Commands(vec![envelope_fields(class, next, serde_json::json!({}))])
}

/// Fold several command envelopes into one `CompoundCommand` — a single undo
/// entry. The compound's `commands` array holds each inner command's `data`
/// object (what `parse_command` consumes), not the `{tag, data}` envelope.
fn compound(commands: Vec<String>, next: &mut u64) -> String {
    let id = *next;
    *next += 1;
    let inner: Vec<serde_json::Value> = commands
        .iter()
        .filter_map(|c| serde_json::from_str::<serde_json::Value>(c).ok())
        .filter_map(|mut v| v.get_mut("data").map(serde_json::Value::take))
        .collect();
    serde_json::json!({
        "tag": "command",
        "data": {
            "className": "CompoundCommand",
            "__cmd_id": id,
            "commands": inner,
        }
    })
    .to_string()
}

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
        on_accept: Box::new(|result, _iface, next| {
            let name = result
                .path
                .strip_prefix(PROJECTS_DIR)
                .unwrap_or(&result.path)
                .trim_end_matches(".sdd")
                .to_string();
            let path = result.path.clone();
            vec![
                envelope_fields(
                    "SetProjectNamePathCommand",
                    next,
                    serde_json::json!({ "name": name, "path": path }),
                ),
                envelope_fields(
                    "SaveProjectInfoCommand",
                    next,
                    serde_json::json!({ "name": name, "path": path, "isNewProject": true }),
                ),
                envelope_fields(
                    "SaveCommand",
                    next,
                    serde_json::json!({ "path": path, "isNewProject": true }),
                ),
            ]
        }),
    }
}

fn save_envelopes(pm: &ProjectManager, next: &mut u64) -> Vec<String> {
    let path = pm.path().unwrap_or_default().to_string();
    let name = pm.name().unwrap_or_default().to_string();
    vec![
        envelope_fields(
            "SaveProjectInfoCommand",
            next,
            serde_json::json!({ "name": name, "path": path, "isNewProject": false }),
        ),
        envelope_fields(
            "SaveCommand",
            next,
            serde_json::json!({ "path": path, "isNewProject": false }),
        ),
    ]
}

// ── Selection ────────────────────────────────────────────────────

/// Remove the current selection as one undo group.
fn remove_selected(models: &mut Models, next: &mut u64) -> ActionResult {
    let selection = models.get::<SelectionManager>().all();
    let commands: Vec<String> = selection
        .iter()
        .map(|(kind, model_id)| {
            envelope_fields(
                "RemoveObjectCommand",
                next,
                serde_json::json!({ "objType": *kind, "modelID": *model_id }),
            )
        })
        .collect();
    if commands.is_empty() {
        ActionResult::None
    } else {
        ActionResult::Commands(vec![compound(commands, next)])
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
