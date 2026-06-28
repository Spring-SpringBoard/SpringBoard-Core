use std::any::Any;

use super::field_descriptor::FieldValueType;
use super::object_data::DefRef;

/// One typed field value, tagged with its name and type so it carries its own
/// meaning without a separate registry lookup.
pub struct FieldValue {
    pub name: &'static str,
    pub value_type: FieldValueType,
    pub value: Box<dyn Any>,
}

impl FieldValue {
    pub fn downcast_ref<T: 'static>(&self) -> Option<&T> {
        self.value.downcast_ref::<T>()
    }
}

/// A full object as typed values: the def reference (engine-backed kinds), the
/// stable modelID, and every modeled field.
pub struct ObjectData {
    pub def: Option<DefRef>,
    pub model_id: Option<i32>,
    pub fields: Vec<FieldValue>,
}

impl ObjectData {
    pub fn field(&self, name: &str) -> Option<&FieldValue> {
        self.fields.iter().find(|field| field.name == name)
    }

    pub fn field_ref<T: 'static>(&self, name: &str) -> Option<&T> {
        self.field(name)?.downcast_ref::<T>()
    }
}
