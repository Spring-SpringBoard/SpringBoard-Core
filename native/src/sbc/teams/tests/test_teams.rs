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

/// AddTeamCommand applies the requested team color in the engine.
fn add_team_sets_color(ctx: &mut TestCtx) -> Result<(), String> {
    let (r, g, b) = (0.25_f32, 0.5_f32, 0.75_f32);
    ctx.route_command(serde_json::json!({
        "className": "AddTeamCommand",
        "name": "TestTeam",
        "color": { "r": r, "g": g, "b": b },
        "allyTeam": 1,
    }));

    let info = ctx
        .sbc
        .interface()
        .teams()
        .get_team_info(1, false)
        .map_err(|e| format!("get_team_info(1): {e:?}"))?;

    // Engine packs team color as (r<<24)|(g<<16)|(b<<8)|a, each channel
    // float*255 truncated (rts/NativeInterface/api/Teams.cpp).
    let packed = info.color;
    let got_r = (packed >> 24) & 0xff;
    let got_g = (packed >> 16) & 0xff;
    let got_b = (packed >> 8) & 0xff;
    let exp = |f: f32| (f * 255.0) as u32;
    if got_r != exp(r) || got_g != exp(g) || got_b != exp(b) {
        return Err(format!(
            "team 1 color not applied: expected rgb ({},{},{}), got ({got_r},{got_g},{got_b})",
            exp(r),
            exp(g),
            exp(b)
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

crate::integration_test!("set_ally", set_ally);
crate::integration_test!("add_team_sets_color", add_team_sets_color);
crate::integration_test!("remove_team_roundtrip", remove_team_roundtrip);
crate::integration_test!("update_team_undo_redo", update_team_undo_redo);
