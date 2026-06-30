use crate::sbc::tests::tests_api::TestCtx;
use crate::sbc::triggers::TriggerManager;
use spring_native::RulesParamValue;

const LIFECYCLE_TRIGGER_ID: i32 = 1;
const RUNTIME_VARIABLE_ID: i32 = 9001;
const RUNTIME_TRIGGER_ID: i32 = 9002;
const RUNTIME_RESULT_PARAM: &str = "sbc_trigger_runtime_variable_value";
const ACTIONS_VARIABLE_ID: i32 = 9011;
const ACTIONS_TRIGGER_ID: i32 = 9012;
const ACTIONS_RESULT_PARAM: &str = "sbc_trigger_actions_runtime_variable_value";

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

fn read_game_rules_param(ctx: &mut TestCtx, name: &str) -> Result<f32, String> {
    let (value, _, exists) = ctx
        .sbc
        .interface()
        .rules_params()
        .get_game_rules_param(name)
        .map_err(|err| format!("GetGameRulesParam({name}) failed: {err:?}"))?;
    if !exists {
        return Err(format!("{name} was not set"));
    }
    let RulesParamValue::Float(value) = value else {
        return Err(format!("{name} came back as {value:?}, expected float"));
    };
    Ok(value)
}

fn add_runtime_variable_and_trigger(
    ctx: &mut TestCtx,
    variable_id: i32,
    trigger_id: i32,
    initial: f32,
    assigned: f32,
) {
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
                "typeName": "number_VARIABLE_ASSIGN",
                "variable": { "type": "var", "value": variable_id },
                "number": { "type": "const", "value": assigned }
            }]
        }
    }));
}

fn read_runtime_variable(
    ctx: &mut TestCtx,
    variable_id: i32,
    result_param: &str,
) -> Result<f32, String> {
    let msg = serde_json::json!({
        "tag": "bridge_test_variable",
        "data": {
            "name": result_param,
            "variableID": variable_id,
        },
    });
    let payload = format!("springboard|native|{msg}");
    match ctx.sbc.interface().messages().send_lua_rules_msg(&payload) {
        Ok(true) => {}
        Ok(false) => return Err(format!("LuaRules rejected variable probe: {payload}")),
        Err(err) => return Err(format!("SendLuaRulesMsg variable probe failed: {err:?}")),
    }
    read_game_rules_param(ctx, result_param)
}

fn assert_runtime_variable(
    ctx: &mut TestCtx,
    variable_id: i32,
    result_param: &str,
    expected: f32,
) -> Result<(), String> {
    let actual = read_runtime_variable(ctx, variable_id, result_param)?;
    if (actual - expected).abs() > 0.01 {
        return Err(format!(
            "Lua runtime did not consume native trigger/variable mirror; variable value={actual}"
        ));
    }
    Ok(())
}

fn trigger_runtime_sees_native_models(ctx: &mut TestCtx) -> Result<(), String> {
    add_runtime_variable_and_trigger(ctx, RUNTIME_VARIABLE_ID, RUNTIME_TRIGGER_ID, 17.0, 23.0);

    send_lua_rules_command(ctx, serde_json::json!({ "className": "StartCommand" }))?;
    send_lua_rules_command(
        ctx,
        serde_json::json!({
            "className": "ExecuteTriggerCommand",
            "triggerID": RUNTIME_TRIGGER_ID,
        }),
    )?;
    assert_runtime_variable(ctx, RUNTIME_VARIABLE_ID, RUNTIME_RESULT_PARAM, 23.0)?;

    Ok(())
}

fn trigger_actions_runtime_sees_native_models(ctx: &mut TestCtx) -> Result<(), String> {
    add_runtime_variable_and_trigger(ctx, ACTIONS_VARIABLE_ID, ACTIONS_TRIGGER_ID, 31.0, 47.0);

    send_lua_rules_command(ctx, serde_json::json!({ "className": "StartCommand" }))?;
    send_lua_rules_command(
        ctx,
        serde_json::json!({
            "className": "ExecuteTriggerActionsCommand",
            "triggerID": ACTIONS_TRIGGER_ID,
        }),
    )?;
    assert_runtime_variable(ctx, ACTIONS_VARIABLE_ID, ACTIONS_RESULT_PARAM, 47.0)?;

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
