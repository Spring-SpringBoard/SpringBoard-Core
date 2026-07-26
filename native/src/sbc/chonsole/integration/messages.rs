//! Bridge messages retained for callers that drive Chonsole through SBC events.

use serde::Deserialize;
use serde_json::Value;

use crate::sbc::chonsole::ChonsoleManager;
use crate::sbc::message_handler::MessageHandler;
use crate::sbc::sbc::SBC;

inventory::submit! { MessageHandler { tag: "chonsole_execute", handler: execute_message } }
inventory::submit! { MessageHandler { tag: "chonsole_suggest", handler: suggest_message } }
inventory::submit! { MessageHandler { tag: "chonsole_history", handler: history_message } }
inventory::submit! { MessageHandler { tag: "chonsole_clear", handler: clear_message } }

#[derive(Deserialize)]
struct InputRequest {
    input: String,
}

fn execute_message(sbc: &mut SBC, data: Value) {
    let Ok(request) = serde_json::from_value::<InputRequest>(data) else {
        log::error!("chonsole_execute requires an input string");
        return;
    };
    sbc.model::<ChonsoleManager>().execute(&request.input);
}

fn suggest_message(sbc: &mut SBC, data: Value) {
    let Ok(request) = serde_json::from_value::<InputRequest>(data) else {
        log::error!("chonsole_suggest requires an input string");
        return;
    };
    log::debug!(
        "chonsole suggestions for {:?}: {:?}",
        request.input,
        sbc.model::<ChonsoleManager>().suggestions(&request.input)
    );
}

fn history_message(sbc: &mut SBC, _data: Value) {
    log::debug!(
        "chonsole history: {:?}",
        sbc.model::<ChonsoleManager>().history()
    );
}

fn clear_message(sbc: &mut SBC, _data: Value) {
    sbc.model::<ChonsoleManager>().clear();
}
