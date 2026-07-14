use serde::{Deserialize, Serialize};
use serde_json::Value;

use crate::sbc::command_system::command::Command;
use crate::sbc::command_system::context::Context;
use crate::sbc::command_system::registry::register_command;
use crate::sbc::objects::codec;
use crate::sbc::objects::ObjectKind;
use crate::sbc::objects::ObjectManager;

// TODO(concrete-commands): replace with AddAreaCommand/AddFeatureCommand/
// AddUnitCommand carrying typed fields, no JSON. See docs/porting/todo.md.
#[derive(Deserialize, Serialize, Debug)]
pub struct AddObjectCommand {
    #[serde(rename = "objType")]
    kind: ObjectKind,
    params: Value,
    #[serde(skip)]
    model_id: Option<i32>,
}

impl AddObjectCommand {
    /// Construct directly for native dispatch. `params` is the object's field
    /// payload (still JSON-typed here — see the concrete-commands TODO).
    pub(crate) fn new(kind: ObjectKind, params: Value) -> Self {
        Self {
            kind,
            params,
            model_id: None,
        }
    }
}

impl Command for AddObjectCommand {
    fn serialize_log(&self) -> serde_json::Value {
        serde_json::to_value(self).unwrap_or(serde_json::Value::Null)
    }

    fn execute(&mut self, ctx: &mut Context) {
        let descriptors = ctx
            .model::<ObjectManager>()
            .field_descriptors(self.kind)
            .unwrap_or_default();
        // JSON ⇄ typed happens here, at the boundary; the model only sees ObjectData.
        let object = codec::json_to_object(&descriptors, &self.params);
        // Reuse the first-run id on redo so the object keeps its stable modelID.
        self.model_id = ctx
            .model::<ObjectManager>()
            .add(self.kind, &object, self.model_id);
    }

    fn unexecute(&mut self, ctx: &mut Context) {
        if let Some(model_id) = self.model_id {
            ctx.model::<ObjectManager>().remove(self.kind, model_id);
        }
    }
}

register_command!(AddObjectCommand, "AddObjectCommand");
