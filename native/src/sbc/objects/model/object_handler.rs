use std::any::Any;

use spring_native::prelude::NativeInterfaceRef;

use super::field_descriptor::ObjectFieldDescriptor;
use super::object_data::DefRef;
use super::object_event::ObjectEvent;
use super::object_kind::ObjectKind;
use super::object_value::{FieldValue, ObjectData};

/// A per-kind object handler. Field values cross as `Any`, whole objects as
/// [`ObjectData`].
pub trait ObjectHandler {
    /// Create an object from typed object data. `model_id` is `Some` on
    /// redo/undo-restore so the object keeps its stable id.
    fn add(&mut self, data: &ObjectData, model_id: Option<i32>) -> Option<i32>;
    /// Remove an object, returning its data so undo can re-add it.
    fn remove(&mut self, model_id: i32) -> Option<ObjectData>;
    fn set_field(&mut self, model_id: i32, name: &str, value: &dyn Any);
    fn set_fields(&mut self, model_id: i32, fields: &[FieldValue]);
    fn field_value(&self, model_id: i32, name: &str) -> Option<Box<dyn Any>>;
    fn descriptors(&self) -> Vec<ObjectFieldDescriptor>;
    fn exists(&self, model_id: i32) -> bool;
    fn latest_model_id(&self) -> i32;
    fn drain_events(&mut self) -> Vec<ObjectEvent>;

    /// Def reference for engine-backed kinds; `None` for editor-only objects.
    fn def(&self, _model_id: i32) -> Option<DefRef> {
        None
    }

    /// Engine springID for engine-backed objects; `None` for editor-only objects.
    fn spring_id(&self, _model_id: i32) -> Option<i32> {
        None
    }

    /// The modelID an engine springID maps to, the reverse of [`spring_id`].
    /// Used to turn a click on a unit into a modelID the editor can select.
    fn model_id_for_spring(&mut self, _spring_id: i32) -> Option<i32> {
        None
    }

    fn descriptor(&self, name: &str) -> Option<ObjectFieldDescriptor> {
        self.descriptors().into_iter().find(|d| d.name == name)
    }

    /// Read every modeled field into typed object data.
    fn read(&self, model_id: i32) -> Option<ObjectData> {
        if !self.exists(model_id) {
            return None;
        }
        let fields = self
            .descriptors()
            .into_iter()
            .filter_map(|descriptor| {
                Some(FieldValue {
                    name: descriptor.name,
                    value_type: descriptor.value_type,
                    value: self.field_value(model_id, descriptor.name)?,
                })
            })
            .collect();
        Some(ObjectData {
            def: self.def(model_id),
            model_id: Some(model_id),
            fields,
        })
    }
}

pub struct ObjectHandlerFactory {
    pub kind: ObjectKind,
    pub make: fn(NativeInterfaceRef) -> Box<dyn ObjectHandler>,
}

inventory::collect!(ObjectHandlerFactory);
