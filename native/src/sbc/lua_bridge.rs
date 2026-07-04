//! Native → Lua message channel: pushes `springboard|native|<json>` envelopes
//! to LuaUI (`SendLuaUIMsg`) and LuaRules (`SendLuaRulesMsg`).

use spring_native::prelude::NativeInterfaceRef;

/// Shared prefix between Lua (`MessageManager.prefix`) and native.
pub const MESSAGE_PREFIX: &str = "springboard";

/// Send a JSON envelope to the widget side. `body` is the full message object
/// (must include a `tag`); it's framed and pushed via SendLuaUIMsg.
pub fn send(interface: &NativeInterfaceRef, body: serde_json::Value) {
    let payload = format!("{MESSAGE_PREFIX}|native|{body}");
    let _ = interface.messages().send_lua_uimsg(&payload, "");
}

/// Send a JSON envelope to the synced LuaRules side.
pub fn send_rules(interface: &NativeInterfaceRef, body: serde_json::Value) {
    let payload = format!("{MESSAGE_PREFIX}|native|{body}");
    let _ = interface.messages().send_lua_rules_msg(&payload);
}

/// Send a widget-side command over the native message channel.
pub fn widget_command(interface: &NativeInterfaceRef, data: serde_json::Value) {
    send(
        interface,
        serde_json::json!({
            "tag": "command",
            "data": data,
        }),
    );
}

/// Send a command to LuaRules. This is used when native owns project data that
/// Lua runtime code still consumes from the synced Lua model.
pub fn rules_command(interface: &NativeInterfaceRef, data: serde_json::Value) {
    send_rules(
        interface,
        serde_json::json!({
            "tag": "command",
            "data": data,
        }),
    );
}
