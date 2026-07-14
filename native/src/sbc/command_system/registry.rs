use std::any::TypeId;
use std::collections::HashMap;
use std::sync::OnceLock;

use log::debug;
use serde::Deserialize;

use super::command::{Command, CommandId, PreviewCommand};

pub type ParsedCommand = (Box<dyn Command>, CommandId);

/// Resolve a payload into a command, or `None` if no handler is registered —
/// during the port, unhandled classes still run in Lua, so that's expected.
pub fn parse_json_command(
    value: serde_json::Value,
) -> Result<Option<ParsedCommand>, CommandParseError> {
    // Native history/resource tracking is keyed by Lua's command id; direct
    // native routes must provide the same field.
    let cmd_id = serde_json::from_value::<CommandIdPeek>(value.clone()).map_err(|source| {
        CommandParseError {
            class: "<unknown>".to_string(),
            source,
        }
    })?;

    // A `__preview` command applies to the engine but stays out of history, so
    // a drag can update the scene every frame.
    let preview = serde_json::from_value::<PreviewPeek>(value.clone())
        .map(|p| p.preview)
        .unwrap_or(false);

    Ok(parse_command(value)?.map(|cmd| {
        let cmd: Box<dyn Command> = if preview {
            Box::new(PreviewCommand { inner: cmd })
        } else {
            cmd
        };
        (cmd, cmd_id.cmd_id)
    }))
}

/// Resolve a payload into a command by `className`, ignoring `__cmd_id`. Used for
/// top-level commands (via [`parse_json_command`]) and for the inner commands a
/// `CompoundCommand` groups.
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

// --- Registration: each command file submits one of these via the macros below.

/// One command's link-time registration, collected by `inventory` and keyed by
/// its Lua `className`.
pub struct CommandRegistration {
    pub class_name: &'static str,
    pub handler: HandlerFn,
    /// Resolves the registered type's `TypeId`, so a `Box<dyn Command>` can be
    /// mapped back to its `className` for logging without per-command impls.
    pub type_id_fn: fn() -> TypeId,
}

/// Turns a command's JSON payload into the command, keyed in the registry by
/// `className`.
pub type HandlerFn = fn(serde_json::Value) -> Result<Option<Box<dyn Command>>, CommandParseError>;

inventory::collect!(CommandRegistration);

/// Resolve a typed command's registered `className`, for the command log.
pub fn class_name_of(command: &dyn Command) -> Option<&'static str> {
    type_id_map().get(&command.type_id()).copied()
}

/// Register a `Deserialize` command: deserializes its payload, then runs it.
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

/// Peeks only the `className` out of a payload, to pick the handler.
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

#[derive(Deserialize)]
struct PreviewPeek {
    #[serde(rename = "__preview", default)]
    preview: bool,
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

    fn water_params(preview: bool) -> serde_json::Value {
        serde_json::json!({
            "className": "SetWaterParamsCommand",
            "__cmd_id": 7,
            "__preview": preview,
            "opts": { "diffuseColor": [1.0, 0.0, 0.0] },
        })
    }

    #[test]
    fn preview_flag_makes_a_command_non_undoable() {
        let (cmd, id) = parse_json_command(water_params(true)).unwrap().unwrap();
        assert_eq!(id, 7, "a preview keeps its command id");
        assert!(!cmd.undoable(), "a preview must stay out of the history");
    }

    #[test]
    fn the_same_command_is_undoable_without_the_preview_flag() {
        let (cmd, _) = parse_json_command(water_params(false)).unwrap().unwrap();
        assert!(cmd.undoable());
    }

    #[test]
    fn dispatch_round_trip_resolves_handler_for_real_payload() {
        let raw = r#"{ "className": "UndoCommand", "__cmd_id": 1 }"#;
        let value: serde_json::Value = serde_json::from_str(raw).unwrap();
        let peeked: ClassPeek = serde_json::from_value(value).unwrap();
        assert_eq!(peeked.class_name, "UndoCommand");
        assert!(
            registry().contains_key(peeked.class_name.as_str()),
            "UndoCommand must be registered via inventory::submit!",
        );
    }
}
