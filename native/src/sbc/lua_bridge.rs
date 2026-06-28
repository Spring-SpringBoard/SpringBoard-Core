//! Native → Lua message channel.
//!
//! The native plugin pushes messages to the widget side via
//! `Spring.SendLuaUIMsg`, framed `springboard|native|<json>`. The widget's
//! `RecieveGadgetMessage` (`op == "native"`) decodes the JSON and routes by
//! `tag`:
//!
//! - `tag: "command"` → reconstruct + execute a `WidgetCommand*` (used by the
//!   command-system widget-notify, e.g. `WidgetCommandExecuted`, and by the
//!   object managers' add/remove widget mirror).
//!
//! Everything goes through one channel + one widget router, so adding a new
//! notification is just another `{tag, ...}` shape — no per-manager plumbing.

use spring_native::prelude::NativeInterfaceRef;

/// Shared prefix between Lua (`MessageManager.prefix`) and native.
pub const MESSAGE_PREFIX: &str = "springboard";

/// Send a JSON envelope to the widget side. `body` is the full message object
/// (must include a `tag`); it's framed and pushed via SendLuaUIMsg.
pub fn send(interface: &NativeInterfaceRef, body: serde_json::Value) {
    let payload = format!("{MESSAGE_PREFIX}|native|{body}");
    let _ = interface.messages().send_lua_uimsg(&payload, "");
}
