use std::any::TypeId;
use std::collections::HashMap;
use std::sync::OnceLock;

use log::debug;
use serde::Deserialize;

use super::command::{Command, CommandId};

pub type ParsedCommand = (Box<dyn Command>, CommandId);

pub fn parse_json_command(
    value: serde_json::Value,
) -> Result<Option<ParsedCommand>, CommandParseError> {
    let cmd_id = serde_json::from_value::<CommandIdPeek>(value.clone()).map_err(|source| {
        CommandParseError {
            class: "<unknown>".to_string(),
            source,
        }
    })?;

    Ok(parse_command(value)?.map(|cmd| (cmd, cmd_id.cmd_id)))
}

pub(crate) fn parse_command(
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

pub struct CommandRegistration {
    pub class_name: &'static str,
    pub handler: HandlerFn,
    pub type_id_fn: fn() -> TypeId,
}

pub type HandlerFn = fn(serde_json::Value) -> Result<Option<Box<dyn Command>>, CommandParseError>;

inventory::collect!(CommandRegistration);

pub fn class_name_of(command: &dyn Command) -> Option<&'static str> {
    type_id_map().get(&command.type_id()).copied()
}

macro_rules! register_command {
    ($ty:ty, $class_name:literal) => {
        inventory::submit! {
            $crate::sbc::command_system::registry::CommandRegistration {
                class_name: $class_name,
                handler: |value| {
                    let cmd: $ty =
                        $crate::sbc::command_system::registry::from_value($class_name, value)?;
                    Ok(Some(Box::new(cmd)))
                },
                type_id_fn: std::any::TypeId::of::<$ty>,
            }
        }
    };
}

pub(crate) use register_command;

pub fn from_value<T: serde::de::DeserializeOwned>(
    class_name: &'static str,
    mut value: serde_json::Value,
) -> Result<T, CommandParseError> {
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

fn type_id_map() -> &'static HashMap<TypeId, &'static str> {
    static CELL: OnceLock<HashMap<TypeId, &'static str>> = OnceLock::new();
    CELL.get_or_init(|| {
        let mut map = HashMap::new();
        for reg in inventory::iter::<CommandRegistration> {
            map.insert((reg.type_id_fn)(), reg.class_name);
        }
        map
    })
}

#[derive(Deserialize)]
struct ClassPeek {
    #[serde(rename = "className")]
    class_name: String,
}

#[derive(Deserialize)]
struct CommandIdPeek {
    #[serde(rename = "__cmd_id")]
    cmd_id: CommandId,
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn class_peek_extracts_class_name() {
        let value = serde_json::json!({
            "className": "TerrainLevelCommand",
            "__cmd_id": 1,
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
    fn registry_lookup_unknown_class_returns_none() {
        assert!(registry().get("DefinitelyNotARealCommand").is_none());
    }

    #[test]
    fn dispatch_round_trip_resolves_handler_for_real_payload() {
        let raw = r#"{ "className": "UndoCommand", "__cmd_id": 1 }"#;
        let value: serde_json::Value = serde_json::from_str(raw).unwrap();
        let peeked: ClassPeek = serde_json::from_value(value).unwrap();
        assert_eq!(peeked.class_name, "UndoCommand");
        assert!(registry().contains_key(peeked.class_name.as_str()));
    }
}
