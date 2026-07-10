//! Building the JSON command envelopes that `SBC::route` consumes.
//!
//! Both the panel and the editing states produce commands this way, so they get
//! the same undo/redo and command-log behaviour as anything Lua sends.

/// A command envelope whose payload sits under `opts`.
pub(crate) fn envelope(class: &str, next: &mut u64, opts: serde_json::Value) -> String {
    let id = *next;
    *next += 1;
    serde_json::json!({
        "tag": "command",
        "data": {
            "className": class,
            "__cmd_id": id,
            "opts": opts,
        }
    })
    .to_string()
}

/// An envelope whose command takes its payload under a key other than `opts`
/// (`SetScenarioInfoCommand` deserializes a `data` object, for instance).
pub(crate) fn envelope_with(
    class: &str,
    next: &mut u64,
    key: &str,
    payload: serde_json::Value,
) -> String {
    let id = *next;
    *next += 1;
    serde_json::json!({
        "tag": "command",
        "data": {
            "className": class,
            "__cmd_id": id,
            key: payload,
        }
    })
    .to_string()
}

/// An envelope whose fields live directly on `data`, with no wrapper key at all
/// (`AddObjectCommand` takes `objType` and `params`).
pub(crate) fn envelope_fields(class: &str, next: &mut u64, fields: serde_json::Value) -> String {
    let id = *next;
    *next += 1;

    let mut data = serde_json::Map::new();
    data.insert("className".to_string(), class.into());
    data.insert("__cmd_id".to_string(), id.into());
    if let serde_json::Value::Object(fields) = fields {
        data.extend(fields);
    }
    serde_json::json!({ "tag": "command", "data": data }).to_string()
}

/// Re-mark envelopes as previews: they apply to the engine but stay out of the
/// undo history. Callers build their envelopes without knowing whether a value
/// is being previewed or committed, so the flag is stamped on afterwards.
pub(crate) fn as_preview(envelopes: Vec<String>) -> Vec<String> {
    envelopes
        .into_iter()
        .map(|envelope| {
            let Ok(mut value) = serde_json::from_str::<serde_json::Value>(&envelope) else {
                return envelope;
            };
            let Some(data) = value.get_mut("data").and_then(|d| d.as_object_mut()) else {
                return envelope;
            };
            data.insert("__preview".to_string(), serde_json::Value::Bool(true));
            value.to_string()
        })
        .collect()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn as_preview_flags_the_command_without_disturbing_it() {
        let mut next = 1;
        let original = envelope(
            "SetWaterParamsCommand",
            &mut next,
            serde_json::json!({ "a": 1 }),
        );
        let marked = as_preview(vec![original]).pop().unwrap();

        let value: serde_json::Value = serde_json::from_str(&marked).unwrap();
        assert_eq!(value["tag"], "command");
        assert_eq!(value["data"]["__preview"], true);
        assert_eq!(value["data"]["className"], "SetWaterParamsCommand");
        assert_eq!(value["data"]["__cmd_id"], 1);
        assert_eq!(value["data"]["opts"]["a"], 1);
    }

    #[test]
    fn envelope_fields_puts_its_keys_on_data() {
        let mut next = 7;
        let raw = envelope_fields(
            "AddObjectCommand",
            &mut next,
            serde_json::json!({ "objType": "unit", "params": { "defName": "armcom" } }),
        );
        let value: serde_json::Value = serde_json::from_str(&raw).unwrap();
        assert_eq!(value["data"]["objType"], "unit");
        assert_eq!(value["data"]["params"]["defName"], "armcom");
        assert_eq!(value["data"]["__cmd_id"], 7);
        assert!(value["data"].get("opts").is_none());
        assert_eq!(next, 8, "the command id is consumed");
    }
}
