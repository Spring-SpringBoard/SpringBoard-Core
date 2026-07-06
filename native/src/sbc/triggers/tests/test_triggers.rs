use crate::sbc::teams::{Team, TeamManager};
use crate::sbc::tests::tests_api::TestCtx;
use crate::sbc::triggers::TriggerManager;

const LIFECYCLE_TRIGGER_ID: i32 = 1;
const RUNTIME_VARIABLE_ID: i32 = 9001;
const RUNTIME_TRIGGER_ID: i32 = 9002;
const ACTIONS_VARIABLE_ID: i32 = 9011;
const ACTIONS_TRIGGER_ID: i32 = 9012;
const RUNTIME_TEAM_ID: i32 = 0;

fn undo(ctx: &mut TestCtx) {
    ctx.route_command(serde_json::json!({ "className": "UndoCommand" }));
}

fn redo(ctx: &mut TestCtx) {
    ctx.route_command(serde_json::json!({ "className": "RedoCommand" }));
}

/// Add → update → remove a trigger with undo/redo at each step (the saved trigger
/// keeps its id across remove→undo). TriggerManager is the truth.
fn trigger_lifecycle(ctx: &mut TestCtx) -> Result<(), String> {
    ctx.route_command(serde_json::json!({
        "className": "AddTriggerCommand",
        "trigger": {
            "id": LIFECYCLE_TRIGGER_ID,
            "name": "onStart",
            "events": [],
            "conditions": [],
            "actions": []
        }
    }));
    let id = LIFECYCLE_TRIGGER_ID;
    if ctx.sbc.model::<TriggerManager>().get_trigger(id).is_none() {
        return Err(format!(
            "AddTriggerCommand did not store a trigger at id {id}"
        ));
    }

    ctx.route_command(serde_json::json!({
        "className": "UpdateTriggerCommand",
        "trigger": { "id": id, "name": "renamed", "events": [], "conditions": [], "actions": [] }
    }));
    {
        let manager = ctx.sbc.model::<TriggerManager>();
        let t = manager
            .get_trigger(id)
            .ok_or("trigger vanished after update")?;
        if t.get("name").and_then(|x| x.as_str()) != Some("renamed") {
            return Err(format!("update didn't take: {t:?}"));
        }
    }

    undo(ctx);
    {
        let manager = ctx.sbc.model::<TriggerManager>();
        let t = manager
            .get_trigger(id)
            .ok_or("trigger vanished after undo")?;
        if t.get("name").and_then(|x| x.as_str()) != Some("onStart") {
            return Err(format!("undo of update didn't restore name: {t:?}"));
        }
    }

    ctx.route_command(serde_json::json!({
        "className": "RemoveTriggerCommand", "triggerID": id
    }));
    if ctx.sbc.model::<TriggerManager>().get_trigger(id).is_some() {
        return Err("RemoveTriggerCommand didn't remove the trigger".to_string());
    }

    undo(ctx);
    {
        let manager = ctx.sbc.model::<TriggerManager>();
        let t = manager
            .get_trigger(id)
            .ok_or("undo of remove didn't restore the trigger")?;
        if t.get("name").and_then(|x| x.as_str()) != Some("onStart") {
            return Err(format!("restored trigger has wrong name: {t:?}"));
        }
    }

    redo(ctx);
    if ctx.sbc.model::<TriggerManager>().get_trigger(id).is_some() {
        return Err("redo of remove didn't drop the trigger".to_string());
    }

    Ok(())
}

fn send_lua_rules_command(ctx: &mut TestCtx, data: serde_json::Value) -> Result<(), String> {
    let msg = serde_json::json!({
        "tag": "command",
        "data": data,
    });
    let payload = format!("springboard|native|{msg}");
    match ctx.sbc.interface().messages().send_lua_rules_msg(&payload) {
        Ok(true) => Ok(()),
        Ok(false) => Err(format!("LuaRules rejected command payload: {payload}")),
        Err(err) => Err(format!("SendLuaRulesMsg failed: {err:?}")),
    }
}

fn add_runtime_variable_and_trigger(
    ctx: &mut TestCtx,
    variable_id: i32,
    trigger_id: i32,
    initial: f32,
    assigned: f32,
) -> i32 {
    let team_id = RUNTIME_TEAM_ID;
    ctx.sbc.model::<TeamManager>().add_team(
        Team {
            name: "Runtime Trigger Team".to_string(),
            metal_max: 1000.0,
            energy_max: 1000.0,
            ..Default::default()
        },
        Some(team_id),
    );
    ctx.route_command(serde_json::json!({
        "className": "AddVariableCommand",
        "variable": {
            "id": variable_id,
            "type": "number",
            "name": "runtime_bonus",
            "value": { "type": "const", "value": initial }
        }
    }));
    ctx.route_command(serde_json::json!({
        "className": "AddTriggerCommand",
        "trigger": {
            "id": trigger_id,
            "enabled": true,
            "name": "runtime native bridge",
            "events": [],
            "conditions": [],
            "actions": [{
                "typeName": "SET_TEAM_RESOURCES",
                "team": { "type": "const", "value": team_id },
                "string": { "type": "const", "value": "metal" },
                "number": { "type": "var", "value": variable_id }
            }]
        }
    }));
    ctx.route_command(serde_json::json!({
        "className": "UpdateVariableCommand",
        "variable": {
            "id": variable_id,
            "type": "number",
            "name": "runtime_bonus",
            "value": { "type": "const", "value": assigned }
        }
    }));
    set_runtime_team_metal(ctx, team_id, 0.0).expect("reset trigger test team metal");
    team_id
}

fn set_runtime_team_metal(ctx: &mut TestCtx, team_id: i32, amount: f32) -> Result<(), String> {
    let synced = ctx.sbc.interface().synced_ctrl();
    let team = synced.team();
    team.set_team_resource(team_id, "metal", amount)
        .map_err(|err| format!("set metal current: {err:?}"))?;
    Ok(())
}

fn assert_runtime_team_metal(ctx: &mut TestCtx, team_id: i32, expected: f32) -> Result<(), String> {
    let actual = ctx
        .sbc
        .interface()
        .teams()
        .get_team_resources(team_id, "metal")
        .map_err(|err| format!("get team metal: {err:?}"))?
        .metalCurrent;
    if (actual - expected).abs() > 0.01 {
        return Err(format!(
            "Lua runtime did not consume native trigger/variable mirror; team metal={actual}"
        ));
    }
    Ok(())
}

fn trigger_runtime_sees_native_models(ctx: &mut TestCtx) -> Result<(), String> {
    let team_id =
        add_runtime_variable_and_trigger(ctx, RUNTIME_VARIABLE_ID, RUNTIME_TRIGGER_ID, 17.0, 23.0);

    send_lua_rules_command(ctx, serde_json::json!({ "className": "StartCommand" }))?;
    send_lua_rules_command(
        ctx,
        serde_json::json!({
            "className": "ExecuteTriggerCommand",
            "triggerID": RUNTIME_TRIGGER_ID,
        }),
    )?;
    assert_runtime_team_metal(ctx, team_id, 23.0)?;

    Ok(())
}

fn trigger_actions_runtime_sees_native_models(ctx: &mut TestCtx) -> Result<(), String> {
    let team_id =
        add_runtime_variable_and_trigger(ctx, ACTIONS_VARIABLE_ID, ACTIONS_TRIGGER_ID, 31.0, 47.0);

    send_lua_rules_command(ctx, serde_json::json!({ "className": "StartCommand" }))?;
    send_lua_rules_command(
        ctx,
        serde_json::json!({
            "className": "ExecuteTriggerActionsCommand",
            "triggerID": ACTIONS_TRIGGER_ID,
        }),
    )?;
    assert_runtime_team_metal(ctx, team_id, 47.0)?;

    Ok(())
}

crate::integration_test!(
    "trigger_actions_runtime_sees_native_models",
    trigger_actions_runtime_sees_native_models
);
crate::integration_test!("trigger_lifecycle", trigger_lifecycle);
crate::integration_test!(
    "trigger_runtime_sees_native_models",
    trigger_runtime_sees_native_models
);
