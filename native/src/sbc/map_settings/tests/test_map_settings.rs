use crate::sbc::tests::tests_api::TestCtx;

fn sun(ctx: &TestCtx, key: &str, mode: &str) -> Result<[f32; 4], String> {
    let (v, ..) = ctx
        .sbc
        .interface()
        .gfx()
        .get_sun(key, mode)
        .map_err(|e| format!("get_sun({key},{mode}): {e:?}"))?;
    Ok(v)
}

fn atmosphere(ctx: &TestCtx, key: &str) -> Result<[f32; 4], String> {
    let (v, ..) = ctx
        .sbc
        .interface()
        .gfx()
        .get_atmosphere(key, "")
        .map_err(|e| format!("get_atmosphere({key}): {e:?}"))?;
    Ok(v)
}

fn water(ctx: &TestCtx, key: &str) -> Result<f32, String> {
    let (v, ..) = ctx
        .sbc
        .interface()
        .gfx()
        .get_water_rendering(key, "")
        .map_err(|e| format!("get_water_rendering({key}): {e:?}"))?;
    Ok(v[0])
}

fn water_texture(ctx: &TestCtx, key: &str) -> Result<String, String> {
    Ok(ctx
        .sbc
        .interface()
        .unsynced_ctrl()
        .get_water_texture(key)
        .map_err(|e| format!("get_water_texture({key}): {e:?}"))?
        .unwrap_or_default())
}

fn map_rendering(ctx: &TestCtx, key: &str) -> Result<[f32; 4], String> {
    let (v, ..) = ctx
        .sbc
        .interface()
        .gfx()
        .get_map_rendering(key, "")
        .map_err(|e| format!("get_map_rendering({key}): {e:?}"))?;
    Ok(v)
}

fn changed4(a: [f32; 4], b: [f32; 4]) -> bool {
    (0..4).any(|i| (a[i] - b[i]).abs() > 1e-4)
}

/// SetSunParametersCommand changes the sun direction (read back via `Gfx::GetSun`)
/// and undo restores it.
fn set_sun_direction(ctx: &mut TestCtx) -> Result<(), String> {
    let before = sun(ctx, "dir", "")?;
    ctx.route_command(serde_json::json!({
        "className": "SetSunParametersCommand",
        "opts": { "dirX": 0.3, "dirY": -0.8, "dirZ": 0.5 }
    }));
    // Engine may renormalize the stored dir, so only require it changed.
    if !changed4(before, sun(ctx, "dir", "")?) {
        return Err(format!("sun dir unchanged: {before:?}"));
    }
    ctx.route_command(serde_json::json!({ "className": "UndoCommand" }));
    let restored = sun(ctx, "dir", "")?;
    for i in 0..3 {
        if (restored[i] - before[i]).abs() > 1e-3 {
            return Err(format!("sun dir not restored: {before:?} vs {restored:?}"));
        }
    }
    Ok(())
}

/// SetSunLightingCommand changes a ground lighting color and undo restores it.
fn set_sun_lighting(ctx: &mut TestCtx) -> Result<(), String> {
    let before = sun(ctx, "ambient", "")?;
    let target = [before[0] + 0.2, before[1] + 0.1, before[2] + 0.3, 1.0];
    ctx.route_command(serde_json::json!({
        "className": "SetSunLightingCommand",
        "opts": { "groundAmbientColor": target }
    }));
    if !changed4(before, sun(ctx, "ambient", "")?) {
        return Err(format!("ground ambient unchanged: {before:?}"));
    }
    ctx.route_command(serde_json::json!({ "className": "UndoCommand" }));
    if changed4(before, sun(ctx, "ambient", "")?) {
        return Err("ground ambient not restored after undo".to_string());
    }
    Ok(())
}

/// SetAtmosphereCommand changes the fog color and undo restores it.
fn set_atmosphere(ctx: &mut TestCtx) -> Result<(), String> {
    let before = atmosphere(ctx, "fogColor")?;
    let target = [before[0] + 0.25, before[1] + 0.15, before[2] + 0.1, 1.0];
    ctx.route_command(serde_json::json!({
        "className": "SetAtmosphereCommand",
        "opts": { "fogColor": target }
    }));
    if !changed4(before, atmosphere(ctx, "fogColor")?) {
        return Err(format!("fog color unchanged: {before:?}"));
    }
    ctx.route_command(serde_json::json!({ "className": "UndoCommand" }));
    if changed4(before, atmosphere(ctx, "fogColor")?) {
        return Err("fog color not restored after undo".to_string());
    }
    Ok(())
}

/// SetWaterParamsCommand changes a scalar water param and undo restores it.
fn set_water_params(ctx: &mut TestCtx) -> Result<(), String> {
    let before = water(ctx, "surfaceAlpha")?;
    let target = if before > 0.5 { 0.2 } else { 0.8 };
    ctx.route_command(serde_json::json!({
        "className": "SetWaterParamsCommand",
        "opts": { "surfaceAlpha": target }
    }));
    if (water(ctx, "surfaceAlpha")? - target).abs() > 1e-3 {
        return Err(format!("surfaceAlpha not applied (wanted {target})"));
    }
    ctx.route_command(serde_json::json!({ "className": "UndoCommand" }));
    if (water(ctx, "surfaceAlpha")? - before).abs() > 1e-3 {
        return Err(format!("surfaceAlpha not restored to {before}"));
    }
    Ok(())
}

/// SetWaterParamsCommand applies a water texture path (via `SetWaterTexture`),
/// read back via `GetWaterTexture`, and undo restores the previous path.
fn set_water_texture(ctx: &mut TestCtx) -> Result<(), String> {
    let before = water_texture(ctx, "normalTexture")?;
    let target = "sbc_test_water_normal.png";
    ctx.route_command(serde_json::json!({
        "className": "SetWaterParamsCommand",
        "opts": { "normalTexture": target }
    }));
    if water_texture(ctx, "normalTexture")? != target {
        return Err(format!("normalTexture not applied (wanted {target})"));
    }
    ctx.route_command(serde_json::json!({ "className": "UndoCommand" }));
    let restored = water_texture(ctx, "normalTexture")?;
    if restored != before {
        return Err(format!(
            "normalTexture not restored: {before:?} vs {restored:?}"
        ));
    }
    Ok(())
}

/// SetMapRenderingParamsCommand changes splat texture scales. No undo (matches
/// Lua, whose unexecute is a stub), so it isn't asserted.
fn set_map_rendering(ctx: &mut TestCtx) -> Result<(), String> {
    let before = map_rendering(ctx, "splatTexScales")?;
    let target = [
        before[0] + 0.05,
        before[1] + 0.06,
        before[2] + 0.07,
        before[3] + 0.08,
    ];
    ctx.route_command(serde_json::json!({
        "className": "SetMapRenderingParamsCommand",
        "opts": { "splatTexScales": target }
    }));
    if !changed4(before, map_rendering(ctx, "splatTexScales")?) {
        return Err(format!("splatTexScales unchanged: {before:?}"));
    }
    Ok(())
}

/// SetGlobalLosCommand toggles an ally-team's global LOS (read back via
/// `Game::GetGlobalLos`). No undo (matches Lua).
fn set_global_los(ctx: &mut TestCtx) -> Result<(), String> {
    let ally = 0;
    let get = |ctx: &TestCtx| ctx.sbc.interface().game().get_global_los(ally);

    ctx.route_command(serde_json::json!({
        "className": "SetGlobalLosCommand", "opts": { "allyTeamID": ally, "value": true }
    }));
    if get(ctx).map_err(|e| format!("get_global_los: {e:?}"))? == 0 {
        return Err("global LOS not set after value=true".to_string());
    }
    ctx.route_command(serde_json::json!({
        "className": "SetGlobalLosCommand", "opts": { "allyTeamID": ally, "value": false }
    }));
    if get(ctx).map_err(|e| format!("get_global_los: {e:?}"))? != 0 {
        return Err("global LOS still set after value=false".to_string());
    }
    Ok(())
}

crate::integration_test!("set_sun_direction", set_sun_direction);
crate::integration_test!("set_sun_lighting", set_sun_lighting);
crate::integration_test!("set_atmosphere", set_atmosphere);
crate::integration_test!("set_water_params", set_water_params);
crate::integration_test!("set_water_texture", set_water_texture);
crate::integration_test!("set_map_rendering", set_map_rendering);
crate::integration_test!("set_global_los", set_global_los);
