//! `command.execute`: the registry that already serves the Lua bridge.

use serde::Deserialize;
use serde_json::{json, Map, Value};

use crate::sbc::command_system::registry::{parse_command, registered_class_names};
use crate::sbc::sbc::SBC;

use super::super::{ControlError, Handled, Reply};

#[derive(Deserialize)]
pub(crate) struct Execute {
    #[serde(rename = "className")]
    pub class_name: String,
    #[serde(flatten)]
    pub fields: Map<String, Value>,
}

pub(crate) fn execute(sbc: &mut SBC, params: Execute) -> Handled {
    let command = parse_command(payload(&params))
        .map_err(|err| ControlError::invalid(err.to_string()))?
        .ok_or_else(|| {
            ControlError::unknown(format!(
                "no native handler for {}. Registered: {}",
                params.class_name,
                registered_class_names().join(", ")
            ))
        })?;
    sbc.submit_command(command);
    Ok(Reply::now(json!({ "className": params.class_name })))
}

/// Commands disagree about where their fields live: some read them off the
/// payload, some out of an `opts` object. Offering both means a caller does not
/// have to know which, and the one the command does not use deserializes away.
fn payload(params: &Execute) -> Value {
    let mut payload = params.fields.clone();
    payload.insert("className".to_string(), params.class_name.clone().into());
    // Do not add an empty `opts` object. Unit commands (for example
    // `UndoCommand`) deserialize from `null`, while commands with fields still
    // receive the compatibility wrapper below.
    if !params.fields.is_empty() {
        payload
            .entry("opts")
            .or_insert_with(|| Value::Object(params.fields.clone()));
    }
    Value::Object(payload)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn unit_commands_have_no_synthetic_options() {
        let params = Execute {
            class_name: "UndoCommand".to_string(),
            fields: Map::new(),
        };

        assert_eq!(payload(&params), json!({ "className": "UndoCommand" }));
    }

    #[test]
    fn field_commands_keep_the_compatibility_options_wrapper() {
        let fields = serde_json::from_value(json!({ "value": 1 })).unwrap();
        let params = Execute {
            class_name: "SomeCommand".to_string(),
            fields,
        };

        assert_eq!(
            payload(&params),
            json!({ "className": "SomeCommand", "value": 1, "opts": { "value": 1 } })
        );
    }
}
