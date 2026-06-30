use spring_native::RulesParamValue;
use std::collections::HashMap;
use std::sync::{Mutex, OnceLock};

use crate::sbc::lua_bridge::MESSAGE_PREFIX;
use crate::sbc::message_handler::MessageHandler;
use crate::sbc::sbc::SBC;
use crate::sbc::tests::tests_api::TestCtx;

inventory::submit! {
    MessageHandler {
        tag: "bridge_test_ack",
        handler: bridge_test_ack,
    }
}

fn acks() -> &'static Mutex<HashMap<String, f32>> {
    static ACKS: OnceLock<Mutex<HashMap<String, f32>>> = OnceLock::new();
    ACKS.get_or_init(|| Mutex::new(HashMap::new()))
}

fn bridge_test_ack(_sbc: &mut SBC, data: serde_json::Value) {
    let Some(name) = data.get("name").and_then(|v| v.as_str()) else {
        return;
    };
    let Some(value) = data.get("value").and_then(|v| v.as_f64()) else {
        return;
    };
    if let Ok(mut acks) = acks().lock() {
        acks.insert(name.to_string(), value as f32);
    }
}

fn bridge_payload(name: &str, value: f32) -> String {
    let msg = serde_json::json!({
        "tag": "bridge_test",
        "data": {
            "name": name,
            "value": value,
        },
    });
    format!("{MESSAGE_PREFIX}|native|{msg}")
}

fn read_game_rules_param(ctx: &mut TestCtx, name: &str) -> Result<f32, String> {
    let (value, _, exists) = ctx
        .sbc
        .interface()
        .rules_params()
        .get_game_rules_param(name)
        .map_err(|err| format!("GetGameRulesParam({name}) failed: {err:?}"))?;
    if !exists {
        return Err(format!("{name} was not set by the bridge"));
    }
    let RulesParamValue::Float(value) = value else {
        return Err(format!("{name} came back as {value:?}, expected float"));
    };
    Ok(value)
}

fn assert_bridge_value(ctx: &mut TestCtx, name: &str, expected: f32) -> Result<(), String> {
    let actual = read_game_rules_param(ctx, name)?;
    if (actual - expected).abs() > 0.01 {
        return Err(format!("{name} = {actual}, expected {expected}"));
    }
    Ok(())
}

fn assert_luaui_ack(name: &str, expected: f32) -> Result<(), String> {
    let actual = acks()
        .lock()
        .map_err(|err| format!("bridge ack lock poisoned: {err}"))?
        .remove(name)
        .ok_or_else(|| format!("{name} was not acknowledged by LuaUI"))?;
    if (actual - expected).abs() > 0.01 {
        return Err(format!("{name} ack = {actual}, expected {expected}"));
    }
    Ok(())
}

fn lua_rules_bridge(ctx: &mut TestCtx) -> Result<(), String> {
    let name = "sbc_luarules_bridge_test";
    let expected = 321.0;
    let payload = bridge_payload(name, expected);
    match ctx.sbc.interface().messages().send_lua_rules_msg(&payload) {
        Ok(true) => assert_bridge_value(ctx, name, expected),
        Ok(false) => Err(format!("LuaRules rejected payload: {payload}")),
        Err(err) => Err(format!("SendLuaRulesMsg failed: {err:?}")),
    }
}

fn luaui_bridge(ctx: &mut TestCtx) -> Result<(), String> {
    let name = "sbc_luaui_bridge_test";
    let expected = 654.0;
    let payload = bridge_payload(name, expected);
    match ctx.sbc.interface().messages().send_lua_uimsg(&payload, "") {
        Ok(true) => assert_luaui_ack(name, expected),
        Ok(false) => Err(format!("LuaUI rejected payload: {payload}")),
        Err(err) => Err(format!("SendLuaUIMsg failed: {err:?}")),
    }
}

crate::integration_test!("lua_rules_bridge", lua_rules_bridge);
crate::integration_test!("luaui_bridge", luaui_bridge);
