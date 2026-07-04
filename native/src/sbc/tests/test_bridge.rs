use std::collections::HashSet;
use std::sync::{Mutex, OnceLock};
use std::time::Duration;

use serde::Deserialize;

use crate::sbc::command_system::command::Command;
use crate::sbc::command_system::context::Context;
use crate::sbc::command_system::io_completion;
use crate::sbc::command_system::registry::register_command;
use crate::sbc::message_handler::MessageHandler;
use crate::sbc::tests::tests_api::TestCtx;
use crate::sbc::{lua_bridge, sbc::SBC};

fn native_lua_async_completion(ctx: &mut TestCtx) -> Result<(), String> {
    let token = unique_token()?;
    let cmd_id = unique_id()?;
    let async_key = ack_key("async", &token, "LuaUI");
    forget_ack(&async_key);

    // Arm before the probe: both reach LuaUI in FIFO order, completion last.
    lua_bridge::widget_command(
        ctx.sbc.interface(),
        serde_json::json!({
            "className": "BridgeTestAwaitCompletionCommand",
            "cmdID": cmd_id,
            "token": token,
        }),
    );
    ctx.route_command(serde_json::json!({
        "className": "BridgeTestCompletionProbeCommand",
        "__cmd_id": cmd_id,
    }));

    if ctx.wait_for_io(Duration::from_secs(5), |_| ack_seen(&async_key)) {
        Ok(())
    } else {
        Err("native command completion did not resolve the LuaUI promise".to_string())
    }
}

crate::integration_test!("native_lua_async_completion", native_lua_async_completion);

fn native_lua_bridge_roundtrip(ctx: &mut TestCtx) -> Result<(), String> {
    let token = unique_token()?;
    let widget_key = ack_key("widget", &token, "LuaUI");
    let rules_key = ack_key("rules", &token, "LuaRules");
    forget_ack(&widget_key);
    forget_ack(&rules_key);

    lua_bridge::widget_command(
        ctx.sbc.interface(),
        serde_json::json!({ "className": "BridgeTestAckCommand", "side": "widget", "token": token }),
    );
    lua_bridge::rules_command(
        ctx.sbc.interface(),
        serde_json::json!({ "className": "BridgeTestAckCommand", "side": "rules", "token": token }),
    );

    if ctx.wait_for_io(Duration::from_secs(5), |_| {
        ack_seen(&widget_key) && ack_seen(&rules_key)
    }) {
        Ok(())
    } else {
        Err("native Lua bridge did not round-trip through LuaUI and LuaRules".to_string())
    }
}

crate::integration_test!("native_lua_bridge_roundtrip", native_lua_bridge_roundtrip);

#[derive(Deserialize)]
struct BridgeTestCompletionProbeCommand;

impl Command for BridgeTestCompletionProbeCommand {
    fn execute(&mut self, ctx: &mut Context) {
        io_completion::submit_native_command_completed(ctx);
    }

    fn undoable(&self) -> bool {
        false
    }
}

register_command!(
    BridgeTestCompletionProbeCommand,
    "BridgeTestCompletionProbeCommand"
);

fn bridge_test_ack(_sbc: &mut SBC, data: serde_json::Value) {
    let Ok(ack) = serde_json::from_value::<BridgeAck>(data) else {
        log::error!("invalid bridge test ack payload");
        return;
    };
    let _ = acks()
        .lock()
        .map(|mut seen| seen.insert(ack_key(&ack.side, &ack.token, &ack.lua_state)));
}

inventory::submit! {
    MessageHandler {
        tag: "bridge_test_ack",
        handler: bridge_test_ack,
    }
}

fn acks() -> &'static Mutex<HashSet<String>> {
    static ACKS: OnceLock<Mutex<HashSet<String>>> = OnceLock::new();
    ACKS.get_or_init(|| Mutex::new(HashSet::new()))
}

fn ack_seen(key: &str) -> bool {
    acks().lock().is_ok_and(|seen| seen.contains(key))
}

fn forget_ack(key: &str) {
    if let Ok(mut seen) = acks().lock() {
        seen.remove(key);
    }
}

fn ack_key(side: &str, token: &str, lua_state: &str) -> String {
    format!("{side}:{token}:{lua_state}")
}

fn unique_token() -> Result<String, String> {
    Ok(format!("bridge-{}", unique_id()?))
}

fn unique_id() -> Result<u64, String> {
    std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .map(|since| since.as_nanos() as u64)
        .map_err(|err| format!("time went backwards: {err}"))
}

#[derive(Deserialize)]
struct BridgeAck {
    side: String,
    token: String,
    #[serde(rename = "luaState")]
    lua_state: String,
}
