use std::time::Duration;

use crate::sbc::project::{EditorState, TextureEditorState};
use crate::sbc::states::{ApplyDir, BrushSettings};
use crate::sbc::tests::tests_api::TestCtx;
use crate::sbc::textures::ui::model::SavedBrush;

/// Editor state is project state, not a command replay: saving and reopening a
/// project restores the brush that the editor will use next and its saved
/// texture-brush presets.
fn editor_state_project_roundtrip(ctx: &mut TestCtx) -> Result<(), String> {
    let root = std::env::temp_dir().join("sbc_editor_state_roundtrip.sdd");
    let state_path = root.join("sb_project_files").join("editor_state.json");
    let _ = std::fs::remove_dir_all(&root);

    let brush = BrushSettings {
        size: 321.0,
        rotation: 17.0,
        strength: 0.42,
        pattern_texture: Some("brush_patterns/terrain/circle.png".to_string()),
        apply_dir: ApplyDir::OnlyLower,
        tex_scale: 3.5,
        tex_rotation: -11.0,
        brush_textures: [("diffuse".to_string(), "brush_textures/rock.png".to_string())]
            .into_iter()
            .collect(),
        texture_enabled: [("diffuse".to_string(), true)].into_iter().collect(),
        ..BrushSettings::default()
    };
    let saved = SavedBrush {
        id: "saved-brush-1".to_string(),
        material: "rock".to_string(),
        brush: brush.clone(),
    };
    *ctx.sbc.model::<BrushSettings>() = brush.clone();
    ctx.sbc
        .model::<EditorState>()
        .set_texture(TextureEditorState {
            saved_brushes: vec![saved],
            selected_brush: Some("saved-brush-1".to_string()),
            selected_material: Some("rock".to_string()),
        });

    ctx.route_command(serde_json::json!({
        "className": "SaveCommand",
        "path": root.to_string_lossy(),
        "isNewProject": true,
    }));
    if !ctx.wait_for_file(&state_path, Duration::from_secs(5)) {
        return Err("SaveCommand did not write sb_project_files/editor_state.json".to_string());
    }

    // Prove LoadProjectCommand hydrates state instead of leaving the current
    // in-memory brush and presets intact.
    *ctx.sbc.model::<BrushSettings>() = BrushSettings::default();
    ctx.sbc
        .model::<EditorState>()
        .set_texture(TextureEditorState::default());
    ctx.route_command(serde_json::json!({
        "className": "LoadProjectCommand",
        "path": root.to_string_lossy(),
    }));
    let restored = ctx.wait_for_io(Duration::from_secs(5), |sbc| {
        let brush = sbc.model::<BrushSettings>().clone();
        let texture = sbc.model::<EditorState>().texture().clone();
        brush.size == 321.0
            && brush.rotation == 17.0
            && brush.apply_dir == ApplyDir::OnlyLower
            && texture.saved_brushes.len() == 1
            && texture.selected_brush.as_deref() == Some("saved-brush-1")
    });
    let _ = std::fs::remove_dir_all(&root);
    if !restored {
        return Err("LoadProjectCommand did not restore editor state".to_string());
    }
    Ok(())
}

crate::integration_test!(
    "editor_state_project_roundtrip",
    editor_state_project_roundtrip
);
