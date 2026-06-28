use serde::Deserialize;
use serde_json::Value;

use crate::sbc::command_system::command::Command;
use crate::sbc::command_system::context::Context;
use crate::sbc::command_system::registry::register_command;
use crate::sbc::objects::codec;
use crate::sbc::objects::model::object_value::FieldValue;
use crate::sbc::objects::ObjectKind;
use crate::sbc::objects::ObjectManager;

/// Sets one or more fields on an object. `key` is polymorphic: a string (+ `value`)
/// sets one field, an object sets many. Unknown fields are dropped when the codec
/// can't match a descriptor, leaving them Lua-side.
// TODO(concrete-commands): replace with SetAreaParamCommand/SetFeatureParamCommand/
// SetUnitParamCommand with typed optional fields, no JSON. See docs/porting/todo.md.
#[derive(Deserialize)]
pub struct SetObjectParamCommand {
    #[serde(rename = "objType")]
    kind: ObjectKind,
    #[serde(rename = "modelID")]
    model_id: i32,
    key: Value,
    #[serde(default)]
    value: Value,

    /// The affected fields' pre-set values, captured on first execute for undo.
    #[serde(skip)]
    old: Option<Vec<FieldValue>>,
}

impl Command for SetObjectParamCommand {
    fn execute(&mut self, ctx: &mut Context) {
        if self.old.is_none() {
            self.old = Some(self.capture_old(ctx.model::<ObjectManager>()));
        }
        let fields = self.new_fields(ctx.model::<ObjectManager>());
        self.apply(ctx, &fields);
    }

    fn unexecute(&mut self, ctx: &mut Context) {
        if let Some(old) = self.old.take() {
            self.apply(ctx, &old);
            self.old = Some(old);
        }
    }
}

impl SetObjectParamCommand {
    /// Read the current typed value of each affected field, for undo.
    fn capture_old(&self, manager: &ObjectManager) -> Vec<FieldValue> {
        self.field_names()
            .into_iter()
            .filter_map(|name| {
                let descriptor = manager.descriptor(self.kind, name)?;
                let value = manager.field_value(self.kind, self.model_id, name)?;
                Some(FieldValue {
                    name: descriptor.name,
                    value_type: descriptor.value_type,
                    value,
                })
            })
            .collect()
    }

    /// Parse the incoming `(key, value)` into typed field values.
    fn new_fields(&self, manager: &ObjectManager) -> Vec<FieldValue> {
        match &self.key {
            Value::String(name) => manager
                .descriptor(self.kind, name)
                .and_then(|descriptor| codec::parse_named_field(&descriptor, &self.value))
                .into_iter()
                .collect(),
            Value::Object(map) => map
                .iter()
                .filter_map(|(name, value)| {
                    let descriptor = manager.descriptor(self.kind, name)?;
                    codec::parse_named_field(&descriptor, value)
                })
                .collect(),
            _ => Vec::new(),
        }
    }

    fn apply(&self, ctx: &mut Context, fields: &[FieldValue]) {
        let manager = ctx.model::<ObjectManager>();
        match &self.key {
            Value::String(_) => {
                if let Some(field) = fields.first() {
                    manager.set_field(self.kind, self.model_id, field.name, &*field.value);
                }
            }
            Value::Object(_) => manager.set_fields(self.kind, self.model_id, fields),
            _ => {}
        }
    }

    /// Field names this command touches.
    fn field_names(&self) -> Vec<&str> {
        match &self.key {
            Value::String(name) => vec![name.as_str()],
            Value::Object(map) => map.keys().map(String::as_str).collect(),
            _ => Vec::new(),
        }
    }
}

register_command!(SetObjectParamCommand, "SetObjectParamCommand");
