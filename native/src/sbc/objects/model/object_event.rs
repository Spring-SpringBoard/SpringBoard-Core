use std::any::Any;

use super::field_descriptor::FieldValueType;
use super::object_kind::ObjectKind;
use super::object_value::ObjectData;

pub enum ObjectEvent {
    Added {
        kind: ObjectKind,
        object_id: i32,
        object: ObjectEventObject,
    },
    Removed {
        kind: ObjectKind,
        object_id: i32,
    },
    Updated {
        kind: ObjectKind,
        object_id: i32,
        name: &'static str,
        value_type: FieldValueType,
        value: Box<dyn Any>,
    },
}

pub enum ObjectEventObject {
    ModelId(i32),
    Data(ObjectData),
}
