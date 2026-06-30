use crate::sbc::tests::tests_api::TestCtx;
use crate::sbc::variables::VariableManager;

/// Add, update, undo, and redo a variable. VariableManager is the truth.
fn variable_lifecycle(ctx: &mut TestCtx) -> Result<(), String> {
    // Tests share one engine boot; reset so this test owns id 1.
    ctx.sbc.model::<VariableManager>().clear();

    ctx.route_command(serde_json::json!({
        "className": "AddVariableCommand",
        "variable": { "type": "number", "name": "hp", "value": 10 }
    }));

    let id = 1; // ids start at 1 after the clear above
    if ctx
        .sbc
        .model::<VariableManager>()
        .get_variable(id)
        .is_none()
    {
        return Err("AddVariableCommand did not store a variable at id 1".to_string());
    }

    ctx.route_command(serde_json::json!({
        "className": "UpdateVariableCommand",
        "variable": { "id": id, "type": "number", "name": "hp", "value": 42 }
    }));
    {
        let manager = ctx.sbc.model::<VariableManager>();
        let v = manager
            .get_variable(id)
            .ok_or("variable vanished after update")?;
        if v.get("value").and_then(|x| x.as_i64()) != Some(42) {
            return Err(format!("update didn't take: {v:?}"));
        }
    }

    ctx.route_command(serde_json::json!({ "className": "UndoCommand" }));
    {
        let manager = ctx.sbc.model::<VariableManager>();
        let v = manager
            .get_variable(id)
            .ok_or("variable vanished after undo")?;
        if v.get("value").and_then(|x| x.as_i64()) != Some(10) {
            return Err(format!("undo of update didn't restore value 10: {v:?}"));
        }
    }

    ctx.route_command(serde_json::json!({ "className": "UndoCommand" }));
    if ctx
        .sbc
        .model::<VariableManager>()
        .get_variable(id)
        .is_some()
    {
        return Err("undo of add didn't remove the variable".to_string());
    }

    ctx.route_command(serde_json::json!({ "className": "RedoCommand" }));
    if ctx
        .sbc
        .model::<VariableManager>()
        .get_variable(id)
        .is_none()
    {
        return Err("redo of add didn't restore the variable".to_string());
    }

    Ok(())
}

crate::integration_test!("variable_lifecycle", variable_lifecycle);
