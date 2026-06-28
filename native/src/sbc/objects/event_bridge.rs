use serde_json::Value;
use spring_native::prelude::NativeInterfaceRef;

use crate::sbc::lua_bridge;
use crate::sbc::objects::codec;
use crate::sbc::objects::model::object_event::{ObjectEvent, ObjectEventObject};
use crate::sbc::objects::ObjectKind;

pub fn emit(interface: &NativeInterfaceRef, events: Vec<ObjectEvent>) {
    for event in events {
        emit_one(interface, event);
    }
}

fn emit_one(interface: &NativeInterfaceRef, event: ObjectEvent) {
    match event {
        ObjectEvent::Added {
            kind,
            object_id,
            object,
        } => {
            let mut data = widget_command("WidgetAddObjectCommand", kind, object_id);
            data["object"] = match object {
                ObjectEventObject::ModelId(model_id) => serde_json::json!(model_id),
                ObjectEventObject::Data(object) => codec::object_to_json(&object),
            };
            send(interface, data);
        }
        ObjectEvent::Removed { kind, object_id } => {
            send(
                interface,
                widget_command("WidgetRemoveObjectCommand", kind, object_id),
            );
        }
        ObjectEvent::Updated {
            kind,
            object_id,
            name,
            value_type,
            value,
        } => {
            let mut data = widget_command("WidgetUpdateObjectCommand", kind, object_id);
            data["name"] = serde_json::json!(name);
            data["value"] = codec::field_to_json(value_type, &*value).unwrap_or(Value::Null);
            send(interface, data);
        }
    }
}

fn widget_command(class_name: &str, kind: ObjectKind, object_id: i32) -> Value {
    serde_json::json!({
        "className": class_name,
        "objType": obj_type(kind),
        "objectID": object_id,
    })
}

fn obj_type(kind: ObjectKind) -> &'static str {
    match kind {
        ObjectKind::Unit => "unit",
        ObjectKind::Feature => "feature",
        ObjectKind::Area => "area",
    }
}

fn send(interface: &NativeInterfaceRef, data: Value) {
    lua_bridge::send(
        interface,
        serde_json::json!({ "tag": "command", "data": data }),
    );
}
