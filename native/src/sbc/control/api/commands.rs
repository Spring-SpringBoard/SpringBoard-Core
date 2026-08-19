use serde::Deserialize;
use serde_json::{json, Map, Value};

use crate::sbc::command_system::registry::parse_command;
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
            ControlError::unknown(format!("no native handler for {}", params.class_name,))
        })?;
    sbc.submit_command(command);
    Ok(Reply::now(json!({ "className": params.class_name })))
}

fn payload(params: &Execute) -> Value {
    let mut payload = params.fields.clone();
    payload.insert("className".to_string(), params.class_name.clone().into());
    Value::Object(payload)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn unit_commands_keep_no_fields() {
        let params = Execute {
            class_name: "UndoCommand".to_string(),
            fields: Map::new(),
        };

        assert_eq!(payload(&params), json!({ "className": "UndoCommand" }));
    }

    #[test]
    fn commands_keep_their_original_field_shape() {
        let fields = serde_json::from_value(json!({ "opts": { "value": 1 } })).unwrap();
        let params = Execute {
            class_name: "SomeCommand".to_string(),
            fields,
        };

        assert_eq!(
            payload(&params),
            json!({ "className": "SomeCommand", "opts": { "value": 1 } })
        );
    }
}
