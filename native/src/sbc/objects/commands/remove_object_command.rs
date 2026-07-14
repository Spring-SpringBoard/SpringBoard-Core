use serde::{Deserialize, Serialize};

use crate::sbc::command_system::command::Command;
use crate::sbc::command_system::context::Context;
use crate::sbc::command_system::registry::register_command;
use crate::sbc::objects::model::object_value::ObjectData;
use crate::sbc::objects::ObjectKind;
use crate::sbc::objects::ObjectManager;

// TODO(concrete-commands): replace with RemoveAreaCommand/RemoveFeatureCommand/
// RemoveUnitCommand, no JSON. See docs/porting/todo.md.
#[derive(Deserialize, Serialize)]
pub struct RemoveObjectCommand {
    #[serde(rename = "objType")]
    kind: ObjectKind,
    #[serde(rename = "modelID")]
    model_id: i32,
    #[serde(skip)]
    saved: Option<ObjectData>,
}

impl RemoveObjectCommand {
    /// Construct directly for native dispatch (no JSON envelope). `saved` is
    /// captured from the live model on first `execute`.
    pub(crate) fn new(kind: ObjectKind, model_id: i32) -> Self {
        Self {
            kind,
            model_id,
            saved: None,
        }
    }
}

impl Command for RemoveObjectCommand {
    fn execute(&mut self, ctx: &mut Context) {
        self.saved = ctx
            .model::<ObjectManager>()
            .remove(self.kind, self.model_id);
    }

    fn unexecute(&mut self, ctx: &mut Context) {
        // Re-add with the original id so it returns unchanged.
        if let Some(saved) = &self.saved {
            ctx.model::<ObjectManager>()
                .add(self.kind, saved, Some(self.model_id));
        }
    }
}

register_command!(RemoveObjectCommand, "RemoveObjectCommand");
