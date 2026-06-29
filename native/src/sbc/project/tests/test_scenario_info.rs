use crate::sbc::project::model::scenario_info_manager::ScenarioInfo;
use crate::sbc::project::ScenarioInfoManager;
use crate::sbc::tests::tests_api::TestCtx;

fn set_info(ctx: &mut TestCtx, data: serde_json::Value) {
    ctx.route_command(serde_json::json!({ "className": "SetScenarioInfoCommand", "data": data }));
}

fn expect(ctx: &mut TestCtx, name: &str, desc: &str, author: &str) -> Result<(), String> {
    let info = ctx.sbc.model::<ScenarioInfoManager>().serialize();
    if info.name != name || info.description != desc || info.author != author {
        return Err(format!(
            "expected (name={name:?}, desc={desc:?}, author={author:?}), got {info:?}"
        ));
    }
    Ok(())
}

/// Set scenario fields, then a partial update, then undo/redo — verifying the
/// Rust ScenarioInfoManager state. Covers the partial-merge (`data.x or self.x`)
/// behaviour: a patch that omits a field must leave it untouched, and undo must
/// restore the full pre-command snapshot.
fn scenario_info_lifecycle(ctx: &mut TestCtx) -> Result<(), String> {
    // Tests share one engine boot; start from a known-empty baseline (a direct
    // reset, not a tracked command, so undo still pops only this test's sets).
    ctx.sbc
        .model::<ScenarioInfoManager>()
        .restore(ScenarioInfo::default());

    set_info(
        ctx,
        serde_json::json!({ "name": "My Map", "author": "gajop" }),
    );
    expect(ctx, "My Map", "", "gajop")?;

    set_info(ctx, serde_json::json!({ "description": "a test scenario" }));
    expect(ctx, "My Map", "a test scenario", "gajop")?;

    ctx.route_command(serde_json::json!({ "className": "UndoCommand" }));
    expect(ctx, "My Map", "", "gajop")?;

    ctx.route_command(serde_json::json!({ "className": "UndoCommand" }));
    expect(ctx, "", "", "")?;

    ctx.route_command(serde_json::json!({ "className": "RedoCommand" }));
    expect(ctx, "My Map", "", "gajop")?;

    Ok(())
}

crate::integration_test!("project_scenario_info_lifecycle", scenario_info_lifecycle);
