use serde_json::{json, Value};

use crate::sbc::command_system::registry;

pub(crate) fn describe() -> Value {
    json!({
        "commands": registry::registered_class_names(),
        "tabs": [],
        "dialogs": [],
    })
}
