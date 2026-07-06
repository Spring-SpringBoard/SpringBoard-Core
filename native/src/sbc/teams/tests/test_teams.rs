use crate::sbc::teams::TeamManager;
use crate::sbc::tests::tests_api::TestCtx;

/// Toggle the alliance between ally-teams 0 and 1 via SetAllyCommand.
fn set_ally(ctx: &mut TestCtx) -> Result<(), String> {
    let allied_before = ctx
        .sbc
        .interface()
        .teams()
        .are_teams_allied(0, 1)
        .map_err(|e| format!("are_teams_allied: {e:?}"))?;

    let target = !allied_before;
    ctx.route_command(serde_json::json!({
        "className": "SetAllyCommand",
        "firstAllyTeamID": 0,
        "secondAllyTeamID": 1,
        "ally": target,
    }));

    let allied_after = ctx
        .sbc
        .interface()
        .teams()
        .are_teams_allied(0, 1)
        .map_err(|e| format!("are_teams_allied after: {e:?}"))?;

    if allied_after != target {
        return Err(format!(
            "set_ally(0,1,{target}) did not take: are_teams_allied(0,1) = {allied_after}"
        ));
    }
    Ok(())
}

/// AddTeamCommand stores the requested team color in the native project model.
fn add_team_stores_color(ctx: &mut TestCtx) -> Result<(), String> {
    let (r, g, b) = (0.25_f32, 0.5_f32, 0.75_f32);
    ctx.route_command(serde_json::json!({
        "className": "AddTeamCommand",
        "name": "TestTeam",
        "color": { "r": r, "g": g, "b": b },
        "allyTeam": 1,
    }));
    let id = ctx.sbc.model::<TeamManager>().latest_id();
    let color = ctx
        .sbc
        .model::<TeamManager>()
        .get_team(id)
        .ok_or_else(|| format!("added team {id} missing from model"))?
        .color;

    if color.r != r || color.g != g || color.b != b {
        return Err(format!(
            "team {id} color not stored: expected ({r},{g},{b}), got ({},{},{})",
            color.r, color.g, color.b
        ));
    }
    Ok(())
}

/// Add a team, then RemoveTeamCommand drops it and undo re-adds it at the same id.
fn remove_team_roundtrip(ctx: &mut TestCtx) -> Result<(), String> {
    ctx.route_command(serde_json::json!({
        "className": "AddTeamCommand", "name": "Doomed", "allyTeam": 1,
    }));
    let id = ctx.sbc.model::<TeamManager>().latest_id();

    ctx.route_command(serde_json::json!({ "className": "RemoveTeamCommand", "teamID": id }));
    if ctx.sbc.model::<TeamManager>().get_team(id).is_some() {
        return Err("RemoveTeamCommand did not drop the team".to_string());
    }

    ctx.route_command(serde_json::json!({ "className": "UndoCommand" }));
    let team = ctx
        .sbc
        .model::<TeamManager>()
        .get_team(id)
        .ok_or("undo of remove did not restore the team")?;
    if team.name != "Doomed" {
        return Err(format!("restored team has wrong name: {:?}", team.name));
    }
    Ok(())
}

/// UpdateTeamCommand changes the team color; undo then redo must round-trip it.
/// Redo re-runs the same command instance, so this also guards the
/// snapshot-once behaviour.
fn update_team_undo_redo(ctx: &mut TestCtx) -> Result<(), String> {
    ctx.route_command(serde_json::json!({
        "className": "AddTeamCommand", "name": "Mutable",
        "color": { "r": 0.1, "g": 0.2, "b": 0.3 }, "allyTeam": 1,
    }));
    let id = ctx.sbc.model::<TeamManager>().latest_id();

    let color_b = |ctx: &mut TestCtx| -> Option<f32> {
        ctx.sbc
            .model::<TeamManager>()
            .get_team(id)
            .map(|t| t.color.b)
    };

    ctx.route_command(serde_json::json!({
        "className": "UpdateTeamCommand",
        "team": { "id": id, "name": "Mutable", "color": { "r": 0.1, "g": 0.2, "b": 0.9 }, "allyTeam": 1 }
    }));
    if color_b(ctx) != Some(0.9) {
        return Err("update did not apply new color".to_string());
    }

    ctx.route_command(serde_json::json!({ "className": "UndoCommand" }));
    if color_b(ctx) != Some(0.3) {
        return Err(format!(
            "undo did not restore color, got {:?}",
            color_b(ctx)
        ));
    }

    ctx.route_command(serde_json::json!({ "className": "RedoCommand" }));
    if color_b(ctx) != Some(0.9) {
        return Err("redo did not re-apply the update".to_string());
    }

    // The redo must not have corrupted the snapshot: a second undo restores 0.3.
    ctx.route_command(serde_json::json!({ "className": "UndoCommand" }));
    if color_b(ctx) != Some(0.3) {
        return Err(format!(
            "undo after redo did not restore color, got {:?}",
            color_b(ctx)
        ));
    }
    Ok(())
}

/// Native team state is seeded from the engine at model construction, so a fresh
/// project has teams to save (an empty team set aborts the engine on reload).
/// The booted map has at least the two player teams + gaia.
fn native_teams_start_populated(ctx: &mut TestCtx) -> Result<(), String> {
    let teams = ctx.sbc.model::<TeamManager>().all_teams();
    if teams.len() < 2 {
        return Err(format!(
            "native model started with too few teams: {} ({:?})",
            teams.len(),
            teams.iter().map(|t| t.id).collect::<Vec<_>>()
        ));
    }
    // Ally teams should come from the engine (not all-zero), and ids preserved.
    if teams.iter().all(|t| t.ally_team == teams[0].ally_team) {
        return Err("all populated teams share one ally team (engine reads failed)".to_string());
    }
    Ok(())
}

crate::integration_test!("set_ally", set_ally);
crate::integration_test!("add_team_stores_color", add_team_stores_color);
crate::integration_test!("remove_team_roundtrip", remove_team_roundtrip);
crate::integration_test!("update_team_undo_redo", update_team_undo_redo);
crate::integration_test!("native_teams_start_populated", native_teams_start_populated);
