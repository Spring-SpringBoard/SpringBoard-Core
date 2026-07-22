//! Project-scoped editor state, saved independently of map data.

use std::any::Any;
use std::collections::BTreeMap;
use std::path::PathBuf;

use log::error;
use serde::{Deserialize, Serialize};

use crate::sbc::command_system::context::Context;
use crate::sbc::command_system::model::{Model, ModelFactory};
use crate::sbc::io::io_api::{IoJob, IoOutcome};
use crate::sbc::project::io_registries::load::ProjectLoadRegistration;
use crate::sbc::project::io_registries::save::ProjectSaveRegistration;
use crate::sbc::project::jobs::WriteTextJob;
use crate::sbc::project::paths::ProjectPaths;
use crate::sbc::sbc::SBC;
use crate::sbc::states::BrushSettings;
use crate::sbc::textures::ui::model::SavedBrush;

const FILE: &str = "editor_state.json";

/// Texture-editor values which are not shared by the other brush editors.
#[derive(Clone, Debug, Default, Deserialize, Serialize)]
#[serde(default, rename_all = "camelCase")]
pub(crate) struct TextureEditorState {
    pub(crate) saved_brushes: Vec<SavedBrush>,
    pub(crate) selected_brush: Option<String>,
    pub(crate) selected_material: Option<String>,
}

/// Live editor state that must survive replacement of a panel instance.
#[derive(Default)]
pub(crate) struct EditorState {
    texture: TextureEditorState,
    brushes: BTreeMap<String, BrushSettings>,
    /// Used while an editor is first opened, before it has its own snapshot.
    fallback_brush: BrushSettings,
}

inventory::submit! {
    ModelFactory { make: |_| Box::new(EditorState::default()) }
}

impl Model for EditorState {
    fn as_any_mut(&mut self) -> &mut dyn Any {
        self
    }
}

impl EditorState {
    pub(crate) fn texture(&self) -> &TextureEditorState {
        &self.texture
    }

    pub(crate) fn set_texture(&mut self, texture: TextureEditorState) {
        self.texture = texture;
    }

    pub(crate) fn brush(&self, editor: &str) -> &BrushSettings {
        self.brushes.get(editor).unwrap_or(&self.fallback_brush)
    }

    pub(crate) fn save_brush(&mut self, editor: &str, brush: BrushSettings) {
        self.fallback_brush = brush.clone();
        self.brushes.insert(editor.to_string(), brush);
    }

    fn load(&mut self, brush: BrushSettings, brushes: BTreeMap<String, BrushSettings>) {
        self.fallback_brush = brush;
        self.brushes = brushes;
    }
}

#[derive(Default, Deserialize, Serialize)]
#[serde(default, rename_all = "camelCase")]
struct StoredEditorState {
    brush: BrushSettings,
    brushes: BTreeMap<String, BrushSettings>,
    texture: TextureEditorState,
}

inventory::submit! {
    ProjectSaveRegistration { save }
}

inventory::submit! {
    ProjectLoadRegistration { load }
}

fn save(ctx: &mut Context, paths: &ProjectPaths, _is_new_project: bool) {
    let state = StoredEditorState {
        brush: ctx.model::<BrushSettings>().clone(),
        brushes: ctx.model::<EditorState>().brushes.clone(),
        texture: ctx.model::<EditorState>().texture().clone(),
    };
    let Ok(text) = serde_json::to_string_pretty(&state) else {
        error!("save editor state: serialize failed");
        return;
    };
    ctx.submit_io(Box::new(WriteTextJob {
        path: paths.file(FILE),
        text,
        what: "save editor state",
    }));
}

fn load(ctx: &mut Context, paths: &ProjectPaths) {
    let path = paths.file(FILE);
    if path.is_file() {
        ctx.submit_io(Box::new(LoadEditorStateJob { path }));
    }
}

struct LoadEditorStateJob {
    path: PathBuf,
}

impl IoJob for LoadEditorStateJob {
    fn run(self: Box<Self>) -> Box<dyn IoOutcome> {
        let result = std::fs::read_to_string(&self.path)
            .map_err(|err| format!("read {}: {err}", self.path.display()))
            .and_then(|text| {
                serde_json::from_str(&text)
                    .map_err(|err| format!("parse {}: {err}", self.path.display()))
            });
        Box::new(LoadEditorStateOutcome(result))
    }
}

struct LoadEditorStateOutcome(Result<StoredEditorState, String>);

impl IoOutcome for LoadEditorStateOutcome {
    fn apply(self: Box<Self>, sbc: &mut SBC) {
        match self.0 {
            Ok(state) => {
                let StoredEditorState {
                    brush,
                    brushes,
                    texture,
                } = state;
                *sbc.model::<BrushSettings>() = brush.clone();
                let editor_state = sbc.model::<EditorState>();
                editor_state.set_texture(texture);
                editor_state.load(brush, brushes);
                sbc.models_mut()
                    .with::<crate::sbc::panels::PanelManager, _>(|panel, models| {
                        panel.editor_state_loaded(models)
                    });
            }
            Err(reason) => error!("load editor state failed: {reason}"),
        }
    }
}
