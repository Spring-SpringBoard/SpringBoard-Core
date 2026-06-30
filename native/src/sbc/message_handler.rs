//! Registry for non-command Lua → native messages, keyed by the envelope `tag`.
//! Each feature self-registers its handlers via `inventory::submit!`, so
//! [`SBC::route`](crate::sbc::sbc::SBC) stays feature-agnostic: it knows only
//! `"command"` and otherwise asks this registry.

use crate::sbc::sbc::SBC;

/// One non-command message handler, collected by `inventory` and keyed by the
/// envelope tag it answers (e.g. `"save_model"`).
pub struct MessageHandler {
    pub tag: &'static str,
    pub handler: fn(&mut SBC, serde_json::Value),
}
inventory::collect!(MessageHandler);

/// Dispatch a tagged message to its registered handler. Returns `false` if no
/// feature registered a handler for `tag`.
pub fn dispatch(sbc: &mut SBC, tag: &str, data: serde_json::Value) -> bool {
    for handler in inventory::iter::<MessageHandler> {
        if handler.tag == tag {
            (handler.handler)(sbc, data);
            return true;
        }
    }
    false
}
