use std::time::Duration;

use crate::sbc::objects::{ObjectKind, ObjectManager};
use crate::sbc::project::{ProjectManager, ScenarioInfoManager};
use crate::sbc::teams::TeamManager;
use crate::sbc::tests::tests_api::TestCtx;
use crate::sbc::triggers::TriggerManager;
use crate::sbc::variables::VariableManager;

fn first_feature_def(ctx: &TestCtx) -> Result<String, String> {
    let defs = ctx.sbc.interface().feature_defs();
    let ids = defs
        .get_feature_def_ids()
        .map_err(|e| format!("get_feature_def_ids: {e:?}"))?;
    for id in ids {
        if let Ok(Some(name)) = defs.get_feature_def_name(id) {
            return Ok(name);
        }
    }
    Err("no feature defs available in this engine boot".to_string())
}

fn model_save_load_roundtrip(ctx: &mut TestCtx) -> Result<(), String> {
    let def_name = first_feature_def(ctx)?;

    ctx.route_command(serde_json::json!({
        "className": "AddObjectCommand",
        "objType": "feature",
        "params": { "defName": def_name, "pos": { "x": 192.0, "y": 0.0, "z": 192.0 } }
    }));
    let feature_model_id = ctx
        .sbc
        .model::<ObjectManager>()
        .latest_model_id(ObjectKind::Feature);

    ctx.route_command(serde_json::json!({
        "className": "AddTeamCommand",
        "name": "Roundtrip Team",
        "color": { "r": 0.2, "g": 0.4, "b": 0.6 },
        "allyTeam": 1
    }));
    let team_id = ctx.sbc.model::<TeamManager>().latest_id();

    ctx.route_command(serde_json::json!({
        "className": "AddVariableCommand",
        "variable": { "id": 77, "name": "roundtrip_var", "type": "number", "value": 7 }
    }));

    ctx.route_command(serde_json::json!({
        "className": "AddTriggerCommand",
        "trigger": {
            "id": 88,
            "name": "roundtrip_trigger",
            "enabled": true,
            "events": [],
            "conditions": [],
            "actions": []
        }
    }));

    ctx.route_command(serde_json::json!({
        "className": "SetScenarioInfoCommand",
        "data": {
            "name": "Roundtrip Scenario",
            "description": "saved through native project IO",
            "author": "integration",
            "version": "1.2.3"
        }
    }));

    let root = std::env::temp_dir().join("sbc_project_model_roundtrip.sdd");
    let model_path = root.join("sb_project_files").join("model.lua");
    let _ = std::fs::remove_dir_all(&root);

    ctx.route_command(serde_json::json!({
        "className": "SaveCommand",
        "path": root.to_string_lossy(),
        "isNewProject": true
    }));
    if !ctx.wait_for_file(&model_path, Duration::from_secs(5)) {
        return Err("SaveCommand did not write sb_project_files/model.lua".to_string());
    }

    ctx.route_command(serde_json::json!({
        "className": "RemoveObjectCommand", "objType": "feature", "modelID": feature_model_id
    }));
    ctx.route_command(serde_json::json!({
        "className": "RemoveTeamCommand", "teamID": team_id
    }));
    ctx.route_command(serde_json::json!({
        "className": "RemoveVariableCommand", "variableID": 77
    }));
    ctx.route_command(serde_json::json!({
        "className": "RemoveTriggerCommand", "triggerID": 88
    }));
    ctx.route_command(serde_json::json!({
        "className": "SetScenarioInfoCommand", "data": { "name": "WIPED" }
    }));

    ctx.route_command(serde_json::json!({
        "className": "LoadProjectCommand",
        "path": root.to_string_lossy()
    }));
    let loaded = ctx.wait_for_io(Duration::from_secs(5), |sbc| {
        sbc.model::<ScenarioInfoManager>().serialize().name == "Roundtrip Scenario"
    });
    if !loaded {
        return Err(format!(
            "LoadProjectCommand did not restore scenario info: got '{}'",
            ctx.sbc.model::<ScenarioInfoManager>().serialize().name
        ));
    }
    {
        let info = ctx.sbc.model::<ScenarioInfoManager>().serialize();
        if info.description != "saved through native project IO"
            || info.author != "integration"
            || info.version != "1.2.3"
        {
            return Err(format!(
                "load_model restored incomplete scenario info: {info:?}"
            ));
        }
    }

    let vars = ctx.sbc.model::<VariableManager>().serialize();
    let has_var = vars.as_array().is_some_and(|list| {
        list.iter().any(|kv| {
            kv.get("variable")
                .and_then(|v| v.get("name"))
                .and_then(|n| n.as_str())
                == Some("roundtrip_var")
        })
    });
    if !has_var {
        return Err("variable 'roundtrip_var' not restored after load".to_string());
    }
    let trigger = ctx
        .sbc
        .model::<TriggerManager>()
        .get_trigger(88)
        .ok_or("trigger 88 not restored after load")?;
    if trigger.get("name").and_then(|v| v.as_str()) != Some("roundtrip_trigger") {
        return Err(format!(
            "trigger 88 restored with wrong payload: {trigger:?}"
        ));
    }
    let team = ctx
        .sbc
        .model::<TeamManager>()
        .get_team(team_id)
        .ok_or("team not restored after load")?;
    if team.name != "Roundtrip Team" || (team.color.b - 0.6).abs() > f32::EPSILON {
        return Err(format!("team restored with wrong payload: {team:?}"));
    }

    if ctx
        .sbc
        .model::<ObjectManager>()
        .spring_id(ObjectKind::Feature, feature_model_id)
        .is_none()
    {
        return Err(format!(
            "feature modelID {feature_model_id} not restored after load"
        ));
    }

    let _ = std::fs::remove_dir_all(&root);
    Ok(())
}

fn set_project_name_path(ctx: &mut TestCtx) -> Result<(), String> {
    ctx.route_command(serde_json::json!({
        "className": "SetProjectNamePathCommand",
        "name": "Alpha",
        "path": "/tmp/alpha.sdd"
    }));
    if ctx.sbc.model::<ProjectManager>().name() != Some("Alpha") {
        return Err(format!(
            "name after first set = {:?}, expected Alpha",
            ctx.sbc.model::<ProjectManager>().name()
        ));
    }
    if ctx.sbc.model::<ProjectManager>().path() != Some("/tmp/alpha.sdd") {
        return Err("path not stored".to_string());
    }

    ctx.route_command(serde_json::json!({
        "className": "SetProjectNamePathCommand",
        "name": "Beta",
        "path": "/tmp/beta.sdd"
    }));
    if ctx.sbc.model::<ProjectManager>().name() != Some("Beta") {
        return Err("rename did not update name".to_string());
    }
    Ok(())
}

fn texture_image_io(ctx: &mut TestCtx) -> Result<(), String> {
    let root = std::env::temp_dir().join("sbc_texture_image_io");
    let project_root = root.join("project.sdd");
    let texture_dir = project_root.join("sb_project_files").join("textures");
    let export_dir = root.join("exports");
    let diffuse_src = root.join("diffuse-src.png");
    let diffuse_mutated_src = root.join("diffuse-mutated-src.png");
    let shading_src = root.join("shading-src.png");
    let shading_mutated_src = root.join("shading-mutated-src.png");
    let diffuse_out = export_dir.join("diffuse.png");
    let _ = std::fs::remove_dir_all(&root);
    std::fs::create_dir_all(&root).map_err(|e| format!("create fixture dir: {e}"))?;

    image::RgbaImage::from_pixel(16, 16, image::Rgba([32, 96, 160, 255]))
        .save(&diffuse_src)
        .map_err(|e| format!("write diffuse fixture: {e}"))?;
    image::RgbaImage::from_pixel(16, 16, image::Rgba([240, 8, 16, 255]))
        .save(&diffuse_mutated_src)
        .map_err(|e| format!("write mutated diffuse fixture: {e}"))?;
    image::RgbaImage::from_pixel(8, 8, image::Rgba([200, 50, 25, 255]))
        .save(&shading_src)
        .map_err(|e| format!("write shading fixture: {e}"))?;
    image::RgbaImage::from_pixel(8, 8, image::Rgba([10, 220, 30, 255]))
        .save(&shading_mutated_src)
        .map_err(|e| format!("write mutated shading fixture: {e}"))?;

    ctx.route_command(serde_json::json!({
        "className": "ImportDiffuseCommand",
        "texturePath": diffuse_src.to_string_lossy()
    }));
    ctx.route_command(serde_json::json!({
        "className": "ImportShadingImageCommand",
        "texType": "specular",
        "texturePath": shading_src.to_string_lossy()
    }));
    // Save the whole project; textures land under sb_project_files/textures/.
    ctx.route_command(serde_json::json!({
        "className": "SaveCommand",
        "path": project_root.to_string_lossy(),
        "isNewProject": true
    }));

    let saved_tile = texture_dir.join("texture-0-0.png");
    if !ctx.wait_for_file(&saved_tile, Duration::from_secs(5)) {
        return Err("SaveCommand did not write texture-0-0.png".to_string());
    }
    let saved_shading = texture_dir.join("shading-specular.png");
    if !ctx.wait_for_file(&saved_shading, Duration::from_secs(5)) {
        return Err("SaveCommand did not write shading-specular.png".to_string());
    }

    // Mutate the live textures, then load the project back and confirm the saved
    // ones are restored (not the mutations).
    ctx.route_command(serde_json::json!({
        "className": "ImportDiffuseCommand",
        "texturePath": diffuse_mutated_src.to_string_lossy()
    }));
    ctx.route_command(serde_json::json!({
        "className": "ImportShadingImageCommand",
        "texType": "specular",
        "texturePath": shading_mutated_src.to_string_lossy()
    }));
    ctx.route_command(serde_json::json!({
        "className": "LoadProjectCommand",
        "path": project_root.to_string_lossy()
    }));

    // Re-export the loaded map through the real command; it writes diffuse.png
    // and the shading textures (specular.png, ...) into the export dir.
    ctx.route_command(serde_json::json!({
        "className": "ExportMapsCommand",
        "path": export_dir.to_string_lossy()
    }));
    if !ctx.wait_for_file(&diffuse_out, Duration::from_secs(5)) {
        return Err("ExportMapsCommand did not write diffuse.png".to_string());
    }
    let diffuse = image::open(&diffuse_out).map_err(|e| format!("open diffuse export: {e}"))?;
    if diffuse.width() == 0 || diffuse.height() == 0 {
        return Err("diffuse export has empty dimensions".to_string());
    }
    let diffuse_pixel = diffuse.to_rgba8().get_pixel(0, 0).0;
    if diffuse_pixel[0] != 32 || diffuse_pixel[1] != 96 || diffuse_pixel[2] != 160 {
        return Err(format!(
            "load_project_textures did not restore saved diffuse pixel: {diffuse_pixel:?}"
        ));
    }

    let specular_out = export_dir.join("specular.png");
    if !ctx.wait_for_file(&specular_out, Duration::from_secs(5)) {
        return Err("export_shading_textures did not write specular.png".to_string());
    }
    let specular_pixel = image::open(&specular_out)
        .map_err(|e| format!("open specular export: {e}"))?
        .to_rgba8()
        .get_pixel(0, 0)
        .0;
    if specular_pixel[0] != 200 || specular_pixel[1] != 50 || specular_pixel[2] != 25 {
        return Err(format!(
            "load_project_textures did not restore saved shading pixel: {specular_pixel:?}"
        ));
    }

    let _ = std::fs::remove_dir_all(&root);
    Ok(())
}

fn project_archive_commands(ctx: &mut TestCtx) -> Result<(), String> {
    let root = std::env::temp_dir().join("sbc_project_archive_commands");
    let project_dir = root.join("project.sdd");
    let archive_dir = root.join("archive");
    let archive_path = root.join("exported_archive");
    let copied_custom = archive_dir.join("custom").join("keep.txt");
    let skipped_project_file = archive_dir.join("sb_project_files").join("model.lua");
    let skipped_mapinfo = archive_dir.join("mapinfo.lua");
    let _ = std::fs::remove_dir_all(&root);

    std::fs::create_dir_all(project_dir.join("custom"))
        .map_err(|e| format!("create custom dir: {e}"))?;
    std::fs::create_dir_all(project_dir.join("sb_project_files"))
        .map_err(|e| format!("create project files dir: {e}"))?;
    std::fs::write(
        project_dir.join("custom").join("keep.txt"),
        "custom payload",
    )
    .map_err(|e| format!("write custom fixture: {e}"))?;
    std::fs::write(project_dir.join("mapinfo.lua"), "skip me")
        .map_err(|e| format!("write mapinfo fixture: {e}"))?;
    std::fs::write(
        project_dir.join("sb_project_files").join("model.lua"),
        "skip me",
    )
    .map_err(|e| format!("write model fixture: {e}"))?;
    std::fs::create_dir_all(&archive_dir).map_err(|e| format!("create archive dir: {e}"))?;

    ctx.route_command(serde_json::json!({
        "className": "CopyCustomProjectFilesCommand",
        "src": project_dir.to_string_lossy(),
        "dest": archive_dir.to_string_lossy()
    }));
    if !ctx.wait_for_file(&copied_custom, Duration::from_secs(5)) {
        return Err("CopyCustomProjectFilesCommand did not copy custom file".to_string());
    }
    if std::fs::read_to_string(&copied_custom).map_err(|e| format!("read copied file: {e}"))?
        != "custom payload"
    {
        return Err("CopyCustomProjectFilesCommand copied wrong custom file contents".to_string());
    }
    if skipped_project_file.exists() || skipped_mapinfo.exists() {
        return Err("CopyCustomProjectFilesCommand copied project-internal files".to_string());
    }

    ctx.route_command(serde_json::json!({
        "className": "ExportProjectCommand",
        "archiveDir": archive_dir.to_string_lossy(),
        "path": archive_path.to_string_lossy()
    }));
    let archive_sdz = archive_path.with_extension("sdz");
    if !ctx.wait_for_file(&archive_sdz, Duration::from_secs(5)) {
        return Err("ExportProjectCommand did not write .sdz archive".to_string());
    }
    let metadata =
        std::fs::metadata(&archive_sdz).map_err(|e| format!("stat exported archive: {e}"))?;
    if metadata.len() == 0 {
        return Err("ExportProjectCommand wrote an empty archive".to_string());
    }

    let _ = std::fs::remove_dir_all(&root);
    Ok(())
}

fn export_spring_archive_command(ctx: &mut TestCtx) -> Result<(), String> {
    let root = std::env::temp_dir().join("sbc_export_spring_archive_command");
    let project_dir = root.join("project.sdd");
    let archive_path = root.join("native_archive_test");
    let archive_sdz = archive_path.with_extension("sdz");
    let _ = std::fs::remove_dir_all(&root);

    std::fs::create_dir_all(project_dir.join("custom"))
        .map_err(|e| format!("create custom dir: {e}"))?;
    std::fs::write(
        project_dir.join("custom").join("keep.txt"),
        "custom payload",
    )
    .map_err(|e| format!("write custom fixture: {e}"))?;

    ctx.route_command(serde_json::json!({
        "className": "ExportSpringArchiveCommand",
        "path": archive_path.to_string_lossy(),
        "projectPath": project_dir.to_string_lossy(),
        "projectName": "native_archive_test",
        "heightmapExtremes": [0.0, 100.0]
    }));

    let archived = ctx.wait_for_io(Duration::from_secs(60), |_| {
        std::fs::metadata(&archive_sdz)
            .map(|metadata| metadata.len() > 0)
            .unwrap_or(false)
            && std::process::Command::new("zipinfo")
                .arg("-1")
                .arg(&archive_sdz)
                .output()
                .map(|output| output.status.success())
                .unwrap_or(false)
    });
    if !archived {
        return Err("ExportSpringArchiveCommand did not write a readable .sdz archive".to_string());
    }

    let listing = std::process::Command::new("zipinfo")
        .arg("-1")
        .arg(&archive_sdz)
        .output()
        .map_err(|e| format!("run zipinfo: {e}"))?;
    if !listing.status.success() {
        return Err(format!("zipinfo failed with {}", listing.status));
    }
    let listing =
        String::from_utf8(listing.stdout).map_err(|e| format!("zipinfo output utf-8: {e}"))?;
    for expected in [
        "mapinfo.lua",
        "mapconfig/s11n_model.lua",
        "LuaGaia/Gadgets/s11n_load_map_features.lua",
        "custom/keep.txt",
    ] {
        if !listing.lines().any(|line| line == expected) {
            return Err(format!(
                "archive is missing {expected}; contents:\n{listing}"
            ));
        }
    }
    if !listing.lines().any(|line| line.starts_with("maps/")) {
        return Err(format!(
            "archive is missing compiled map outputs; contents:\n{listing}"
        ));
    }

    let _ = std::fs::remove_dir_all(&root);
    Ok(())
}

fn reload_into_project_rejects_incompatible_game(ctx: &mut TestCtx) -> Result<(), String> {
    let root = std::env::temp_dir().join("sbc_reload_rejects_incompatible_game.sdd");
    let script_path = root.join("sb_project_files").join("script.txt");
    let _ = std::fs::remove_dir_all(&root);
    std::fs::create_dir_all(script_path.parent().ok_or("script has no parent")?)
        .map_err(|e| format!("create script dir: {e}"))?;
    std::fs::write(
        &script_path,
        r#"[GAME]
{
    gameType = Some Other Game 1.0;
    mapName = test;
    startPosType = 0;

    [modOptions]
    {
        _sb_game_name = definitely-incompatible-game;
        _sb_game_version = 0.0;
    }

    [TEAM0] { TeamLeader = 0; AllyTeam = 0; }
    [ALLYTEAM0] { NumAllies = 0; }
}
"#,
    )
    .map_err(|e| format!("write script fixture: {e}"))?;

    ctx.route_command(serde_json::json!({
        "className": "ReloadIntoProjectCommand",
        "path": root.to_string_lossy(),
        "modOptions": {
            "_sl_write_path": "/tmp/sbc-test"
        },
        "gameName": "editor-game",
        "gameVersion": "1.0"
    }));

    ctx.sbc.drain_io();
    if !script_path.is_file() {
        return Err("ReloadIntoProjectCommand fixture disappeared".to_string());
    }

    let _ = std::fs::remove_dir_all(&root);
    Ok(())
}

crate::integration_test!("model_save_load_roundtrip", model_save_load_roundtrip);
crate::integration_test!(
    "export_spring_archive_command",
    export_spring_archive_command
);
crate::integration_test!("project_archive_commands", project_archive_commands);
crate::integration_test!(
    "reload_into_project_rejects_incompatible_game",
    reload_into_project_rejects_incompatible_game
);
crate::integration_test!("set_project_name_path", set_project_name_path);
crate::integration_test!("texture_image_io", texture_image_io);
