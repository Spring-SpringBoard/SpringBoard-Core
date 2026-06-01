use std::collections::HashMap;
use std::sync::OnceLock;

use log::debug;
use serde::Deserialize;

use super::command::Command;

/// Resolve a payload into a command, or `None` if no handler is registered —
/// during the port, unhandled classes still run in Lua, so that's expected.
pub fn parse_json_command(
    value: serde_json::Value,
) -> Result<Option<Box<dyn Command>>, CommandParseError> {
    let class_name = serde_json::from_value::<ClassPeek>(value.clone())
        .map_err(|source| CommandParseError {
            class: "<unknown>".to_string(),
            source,
        })?
        .class_name;

    match registry().get(class_name.as_str()).copied() {
        Some(handler) => handler(value),
        None => {
            debug!("no Rust handler for {class_name}; left to Lua");
            Ok(None)
        }
    }
}

#[derive(thiserror::Error, Debug)]
#[error("failed to deserialize {class}: {source}")]
pub struct CommandParseError {
    class: String,
    source: serde_json::Error,
}

// --- Registration: each command file submits one of these via the macros below.

/// One command's link-time registration, collected by `inventory` and keyed by
/// its Lua `className`.
pub struct CommandRegistration {
    pub class_name: &'static str,
    pub handler: HandlerFn,
}

/// Turns a command's JSON payload into the command, keyed in the registry by
/// `className`.
pub type HandlerFn = fn(serde_json::Value) -> Result<Option<Box<dyn Command>>, CommandParseError>;

inventory::collect!(CommandRegistration);

/// Register a `Deserialize` command: deserializes its payload, then runs it.
macro_rules! register_command {
    ($ty:ty, $class_name:literal) => {
        inventory::submit! {
            $crate::sbc::commands::command_system::registry::CommandRegistration {
                class_name: $class_name,
                handler: |value| {
                    let cmd: $ty =
                        $crate::sbc::commands::command_system::registry::from_value($class_name, value)?;
                    Ok(Some(Box::new(cmd)))
                },
            }
        }
    };
}

pub(crate) use register_command;

/// Deserialize a payload, tagging failures with the class name. Used by the
/// `register_command!`-generated handlers.
pub fn from_value<T: serde::de::DeserializeOwned>(
    class_name: &'static str,
    mut value: serde_json::Value,
) -> Result<T, CommandParseError> {
    // Strip wire-only fields before deserializing so command structs do not
    // model them. Empty maps become null so unit structs can deserialize.
    if let serde_json::Value::Object(map) = &mut value {
        map.remove("className");
        map.remove("__cmd_id");
        if map.is_empty() {
            value = serde_json::Value::Null;
        }
    }
    serde_json::from_value(value).map_err(|source| CommandParseError {
        class: class_name.to_string(),
        source,
    })
}

// --- Internals.

fn registry() -> &'static HashMap<&'static str, HandlerFn> {
    static CELL: OnceLock<HashMap<&'static str, HandlerFn>> = OnceLock::new();
    CELL.get_or_init(|| {
        let mut map = HashMap::new();
        for reg in inventory::iter::<CommandRegistration> {
            if map.insert(reg.class_name, reg.handler).is_some() {
                panic!("duplicate command registration for {}", reg.class_name);
            }
        }
        map
    })
}

/// Peeks only the `className` out of a payload, to pick the handler.
#[derive(Deserialize)]
struct ClassPeek {
    #[serde(rename = "className")]
    class_name: String,
}

#[cfg(test)]
mod tests {
    use super::*;

    fn registered_class_names() -> Vec<&'static str> {
        let mut names: Vec<_> = registry().keys().copied().collect();
        names.sort_unstable();
        names
    }

    #[test]
    fn class_peek_extracts_class_name() {
        let value = serde_json::json!({
            "className": "TerrainLevelCommand",
            "opts": { "extra": "stuff" }
        });
        let peeked: ClassPeek = serde_json::from_value(value).unwrap();
        assert_eq!(peeked.class_name, "TerrainLevelCommand");
    }

    #[test]
    fn class_peek_missing_field_fails() {
        let value = serde_json::json!({ "wrong": "field" });
        assert!(serde_json::from_value::<ClassPeek>(value).is_err());
    }

    #[test]
    fn registry_has_no_duplicate_class_names() {
        let names = registered_class_names();
        let mut sorted = names.clone();
        sorted.sort_unstable();
        sorted.dedup();
        assert_eq!(
            names.len(),
            sorted.len(),
            "duplicate class names registered: {names:?}"
        );
    }

    #[test]
    fn registry_lookup_unknown_class_returns_none() {
        assert!(registry().get("DefinitelyNotARealCommand").is_none());
    }

    #[test]
    fn dispatch_round_trip_resolves_handler_for_real_payload() {
        let raw = r#"{ "className": "UndoCommand" }"#;
        let value: serde_json::Value = serde_json::from_str(raw).unwrap();
        let peeked: ClassPeek = serde_json::from_value(value).unwrap();
        assert_eq!(peeked.class_name, "UndoCommand");
        assert!(
            registry().contains_key(peeked.class_name.as_str()),
            "UndoCommand must be registered via inventory::submit!",
        );
    }
}
