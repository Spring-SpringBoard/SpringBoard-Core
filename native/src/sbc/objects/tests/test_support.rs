use crate::sbc::tests::tests_api::TestCtx;

/// Route a command payload the way Lua does (wrapped, with a `__cmd_id`).
pub(crate) fn dispatch(ctx: &mut TestCtx, data: serde_json::Value) {
    ctx.route_command(data);
}

/// A feature def from the engine's built-in content — works in the standalone
/// smoke boot, unlike unit defs which need a game's unit defs.
pub(crate) fn first_feature_def(ctx: &TestCtx) -> Result<String, String> {
    all_feature_defs(ctx)?
        .into_iter()
        .next()
        .ok_or("no feature defs available in this engine boot".to_string())
}

pub(crate) fn all_feature_defs(ctx: &TestCtx) -> Result<Vec<String>, String> {
    let defs = ctx.sbc.interface().feature_defs();
    let ids = defs
        .get_feature_def_ids()
        .map_err(|e| format!("get_feature_def_ids: {e:?}"))?;
    let mut names = Vec::new();
    for id in ids {
        if let Ok(Some(name)) = defs.get_feature_def_name(id) {
            names.push(name);
        }
    }
    names.sort();
    names.dedup();
    Ok(names)
}
