//! Builds the Lua/text files that describe a saved project: `script.txt`,
//! `project.lua`, and `modinfo.lua`.

use serde_json::{json, Map, Value};

use crate::sbc::project::ops::lua_writer;
use crate::sbc::project::{ProjectData, ScenarioInfo};
use crate::sbc::teams::Team;

pub(crate) fn project_lua(project: &ProjectData) -> String {
    lua_writer::table_file(
        &serde_json::to_value(project).unwrap_or_else(|_| Value::Object(Map::new())),
    )
}

pub(crate) fn start_script(project: &ProjectData, teams: &[Team]) -> String {
    let game = project.game.as_ref().and_then(Value::as_object);
    let game_name = game
        .and_then(|g| g.get("name"))
        .and_then(Value::as_str)
        .unwrap_or("");
    let game_version = game
        .and_then(|g| g.get("version"))
        .and_then(Value::as_str)
        .unwrap_or("");
    let map_opts = project
        .random_map_options
        .as_ref()
        .cloned()
        .unwrap_or_else(|| json!({}));
    let mut script = Map::new();
    script.insert(
        "gameType".to_string(),
        Value::String(format!("{game_name} {game_version}")),
    );
    script.insert(
        "mapName".to_string(),
        Value::String(project.map_name.clone().unwrap_or_default()),
    );
    // `mapSeed` opts into the engine's blank-map generator. Keep it for an
    // explicitly generated blank map, and for the engine's initial generated
    // map (which is the map captured by Save As before a project exists).
    // Archive-backed maps must omit it or Spring replaces their SMF with a
    // fresh blank map.
    let map_seed = map_opts.get("mapSeed").cloned().or_else(|| {
        project
            .map_name
            .as_deref()
            .filter(|name| *name == "SB_Blank_Map" || name.starts_with("sb_initial_blank_"))
            .map(|_| Value::from(42))
    });
    if let Some(map_seed) = map_seed {
        script.insert("mapSeed".to_string(), map_seed);
    }
    script.insert("isHost".to_string(), Value::Bool(true));
    script.insert("hostIP".to_string(), Value::String("127.0.0.1".to_string()));
    script.insert("gameStartDelay".to_string(), Value::from(0));
    script.insert("startPosType".to_string(), Value::from(2));
    script.insert("mutators".to_string(), Value::Null);
    script.insert(
        "modOptions".to_string(),
        json!({
            "deathmode": "neverend",
            "_sb_game_name": game_name,
            "_sb_game_version": game_version,
            "sb_game_mode": "dev",
            "project_path": project.path.clone().unwrap_or_default(),
        }),
    );
    script.insert(
        "mapOptions".to_string(),
        json!({
            "new_map_x": map_opts.get("new_map_x").cloned().unwrap_or(Value::Null),
            "new_map_y": map_opts.get("new_map_y").cloned().unwrap_or(Value::Null),
        }),
    );

    let mut players = Vec::new();
    let mut ais = Vec::new();
    let mut script_teams = Vec::new();
    for team in teams.iter().filter(|team| !bool_extra(team, "gaia")) {
        let team_idx = script_teams.len() + 1;
        script_teams.push(json!({
            "teamLeader": 0,
            "allyTeam": team.ally_team,
            "RGBColor": format!("{} {} {}", team.color.r, team.color.g, team.color.b),
            "side": non_empty_side(team),
        }));
        if bool_extra(team, "ai") {
            ais.push(json!({
                "name": team.name,
                "team": team_idx,
                "shortName": "NullAI",
                "version": "",
                "isFromDemo": false,
                "host": 0,
            }));
        } else {
            players.push(json!({
                "name": team.name,
                "team": team_idx,
                "spectator": true,
                "isFromDemo": true,
            }));
        }
    }
    script.insert("numPlayers".to_string(), Value::from(players.len()));
    script.insert(
        "numUsers".to_string(),
        Value::from(players.len() + ais.len()),
    );
    for (i, value) in players.into_iter().enumerate() {
        script.insert(format!("player{i}"), value);
    }
    for (i, value) in ais.into_iter().enumerate() {
        script.insert(format!("ai{i}"), value);
    }
    for (i, value) in script_teams.iter().cloned().enumerate() {
        script.insert(format!("team{i}"), value);
    }
    for i in 0..script_teams.len() {
        script.insert(format!("allyTeam{i}"), json!({ "numAllies": 1 }));
    }
    for (i, mutator) in project.mutators.iter().enumerate() {
        script.insert(format!("mutator{i}"), Value::String(mutator.clone()));
    }

    lua_writer::start_script_table("GAME", &Value::Object(script), 0)
}

pub(crate) fn modinfo(scenario_info: &ScenarioInfo, project: &ProjectData) -> String {
    // A project is a mutator archive, not a map archive. Its name must match
    // the mutator saved into script.txt so Spring can resolve it on reload.
    let project_name = project.name.as_deref().unwrap_or(&scenario_info.name);
    let game = project.game.as_ref().and_then(Value::as_object);
    let game_name = game
        .and_then(|g| g.get("name"))
        .and_then(Value::as_str)
        .unwrap_or("");
    let game_version = game
        .and_then(|g| g.get("version"))
        .and_then(Value::as_str)
        .unwrap_or("");
    format!(
        r#"local modinfo = {{
    name = "{}",
    shortName = "{}",
    version    = "{}",
    game = "{}",
    shortGame = "{}",
    mutator = "Official",
    description = "{}",
    modtype = "1",
    depend = {{
        "{} {}",
    }}
}}
return modinfo"#,
        lua_escape(project_name),
        lua_escape(project_name),
        "1.0",
        lua_escape(project_name),
        lua_escape(project_name),
        lua_escape(&scenario_info.description),
        lua_escape(game_name),
        lua_escape(game_version),
    )
}

fn bool_extra(team: &Team, key: &str) -> bool {
    team.extra
        .get(key)
        .and_then(Value::as_bool)
        .unwrap_or(false)
}

fn non_empty_side(team: &Team) -> Value {
    let side = team.side.0.trim();
    if side.is_empty() {
        Value::Null
    } else {
        Value::String(side.to_string())
    }
}

fn lua_escape(value: &str) -> String {
    value.replace('\\', "\\\\").replace('"', "\\\"")
}
