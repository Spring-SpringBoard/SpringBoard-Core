//! Reads a saved project's start script and rebuilds its `[GAME]` section for
//! reloading into the current editor (merging persistent mod options, checking
//! game/version compatibility).

use serde_json::{Map, Value};

use crate::sbc::project::ops::lua_writer;

/// Produce the reload start-script from a saved `script.txt`, or an error.
pub(crate) fn start_script(
    saved_script: &str,
    persistent_options: &Map<String, Value>,
    game_name: &str,
    game_version: &str,
) -> Result<String, String> {
    let mut game = parse_start_script_game(saved_script)?;
    // A start script with no teams makes the engine abort in
    // CTeamHandler::LoadFromSetup, so refuse the reload rather than crash.
    if !game
        .keys()
        .any(|key| key.to_lowercase().starts_with("team"))
    {
        return Err("saved start script has no teams; refusing to reload".to_string());
    }
    update_start_script_game(&mut game, persistent_options, game_name, game_version)?;
    Ok(lua_writer::start_script_table(
        "GAME",
        &Value::Object(game),
        0,
    ))
}

fn update_start_script_game(
    game: &mut Map<String, Value>,
    persistent_options: &Map<String, Value>,
    game_name: &str,
    game_version: &str,
) -> Result<(), String> {
    let mod_options = object_entry(game, "modOptions");
    merge_values(mod_options, persistent_options);

    let script_game = string_entry(mod_options, "_sb_game_name");
    let script_version = string_entry(mod_options, "_sb_game_version");
    match script_game.as_deref() {
        None => {
            log::info!("project was saved with an older editor; please upgrade manually");
            return Ok(());
        }
        Some(saved_game) if saved_game != game_name => {
            log::warn!(
                "trying to open project in incompatible editor: editor={game_name} project={saved_game}"
            );
            return Ok(());
        }
        Some(_) => {}
    }
    if script_version
        .as_deref()
        .is_some_and(|saved| saved != game_version)
    {
        log::info!(
            "opening project saved with different game version: editor={game_version} project={}",
            script_version.unwrap_or_default()
        );
    }

    mod_options.remove("_sb_game_name");
    mod_options.remove("_sb_game_version");
    game.insert(
        "gameType".to_string(),
        Value::String(format!("{game_name} {game_version}")),
    );
    game.entry("players".to_string())
        .or_insert_with(|| Value::Object(Map::new()));
    game.entry("ais".to_string())
        .or_insert_with(|| Value::Object(Map::new()));
    game.insert("startPosType".to_string(), Value::from(2));
    Ok(())
}

fn parse_start_script_game(text: &str) -> Result<Map<String, Value>, String> {
    let root = parse_tdf(text)?;
    root.get("GAME")
        .or_else(|| root.get("game"))
        .and_then(Value::as_object)
        .cloned()
        .ok_or_else(|| "start script has no [GAME] section".to_string())
}

/// Parse a Spring TDF start script into nested maps. Handles both multi-line
/// sections (`[NAME]` / `{` / `}` on their own lines) and the inline form
/// `[NAME] { key=val; ... }` that `project_info::start_script` emits.
fn parse_tdf(text: &str) -> Result<Map<String, Value>, String> {
    let mut stack: Vec<(String, Map<String, Value>)> = vec![(String::new(), Map::new())];
    let mut pending_section: Option<String> = None;
    let mut buf = String::new();

    for line in text.lines() {
        let line = line.split("//").next().unwrap_or("");
        for ch in line.chars() {
            match ch {
                '[' => buf.clear(),
                ']' => {
                    pending_section = Some(buf.trim().to_string());
                    buf.clear();
                }
                '{' => {
                    let section = pending_section
                        .take()
                        .ok_or_else(|| "section body without section name".to_string())?;
                    stack.push((section, Map::new()));
                    buf.clear();
                }
                '}' => {
                    flush_assignment(&mut buf, &mut stack)?;
                    let (section, map) = stack
                        .pop()
                        .ok_or_else(|| "unbalanced section close".to_string())?;
                    let (_, parent) = stack
                        .last_mut()
                        .ok_or_else(|| "closed root section".to_string())?;
                    parent.insert(section, Value::Object(map));
                }
                ';' => flush_assignment(&mut buf, &mut stack)?,
                _ => buf.push(ch),
            }
        }
        flush_assignment(&mut buf, &mut stack)?;
    }
    if stack.len() != 1 {
        return Err("unclosed start script section".to_string());
    }
    Ok(stack.pop().expect("root exists").1)
}

/// Commit a buffered `key=value` assignment (if any) into the current section.
fn flush_assignment(
    buf: &mut String,
    stack: &mut [(String, Map<String, Value>)],
) -> Result<(), String> {
    let text = buf.trim();
    if !text.is_empty() {
        if let Some((key, value)) = text.split_once('=') {
            let (_, current) = stack
                .last_mut()
                .ok_or_else(|| "missing current section".to_string())?;
            current.insert(
                key.trim().to_string(),
                Value::String(value.trim().to_string()),
            );
        }
    }
    buf.clear();
    Ok(())
}

fn object_entry<'a>(map: &'a mut Map<String, Value>, key: &str) -> &'a mut Map<String, Value> {
    let value = map
        .entry(key.to_string())
        .or_insert_with(|| Value::Object(Map::new()));
    if !value.is_object() {
        *value = Value::Object(Map::new());
    }
    value.as_object_mut().expect("value was just made object")
}

fn merge_values(target: &mut Map<String, Value>, source: &Map<String, Value>) {
    for (key, value) in source {
        target.insert(key.clone(), value.clone());
    }
}

fn string_entry(map: &Map<String, Value>, key: &str) -> Option<String> {
    map.get(key)
        .and_then(Value::as_str)
        .map(ToString::to_string)
}

#[cfg(test)]
mod tests {
    use super::*;

    // The saved start script writes sections inline (`[TEAM0] { ... }`); the
    // reload parser must keep those (an empty team list aborts the engine).
    #[test]
    fn parses_inline_sections_and_keeps_teams() {
        let script = "\
[GAME]
{
  MapName=some_map;
  [PLAYER0] { Name=Manual; Team=0; Spectator=1; }
  [TEAM0]   { TeamLeader=0; AllyTeam=0; }
  [TEAM1]   { TeamLeader=0; AllyTeam=1; }
  [ALLYTEAM0] { NumAllies=0; }
}
";
        let root = parse_tdf(script).expect("parse");
        let game = root["GAME"].as_object().expect("GAME");
        assert_eq!(game["MapName"], Value::from("some_map"));
        assert_eq!(game["TEAM0"]["AllyTeam"], Value::from("0"));
        assert_eq!(game["TEAM1"]["AllyTeam"], Value::from("1"));
        assert_eq!(game["PLAYER0"]["Name"], Value::from("Manual"));
        assert!(game.contains_key("ALLYTEAM0"));
    }

    #[test]
    fn parse_start_script_keeps_teams_through_rebuild() {
        let script = "[GAME]\n{\n[TEAM0] { AllyTeam=0; }\n[TEAM1] { AllyTeam=1; }\n}\n";
        let game = parse_start_script_game(script).expect("game");
        let rebuilt = lua_writer::start_script_table("GAME", &Value::Object(game), 0);
        assert!(
            rebuilt.contains("[TEAM0]"),
            "rebuilt lost TEAM0:\n{rebuilt}"
        );
        assert!(
            rebuilt.contains("[TEAM1]"),
            "rebuilt lost TEAM1:\n{rebuilt}"
        );
    }

    #[test]
    fn refuses_teamless_start_script() {
        let script = "[GAME]\n{\nMapName=blank;\n[PLAYER0] { Name=Manual; }\n}\n";
        let err = start_script(script, &Map::new(), "g", "v").unwrap_err();
        assert!(err.contains("no teams"), "unexpected error: {err}");
    }
}
