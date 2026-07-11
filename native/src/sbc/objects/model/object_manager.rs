use std::any::Any;
use std::collections::HashMap;

use spring_native::prelude::NativeInterfaceRef;

use super::field_descriptor::ObjectFieldDescriptor;
use super::object_event::ObjectEvent;
use super::object_handler::{ObjectHandler, ObjectHandlerFactory};
use super::object_kind::ObjectKind;
use super::object_value::{FieldValue, ObjectData};
use crate::sbc::command_system::model::{Model, ModelFactory};

inventory::submit! { ModelFactory { make: |iface| Box::new(ObjectManager::new(iface)) } }

/// Routes object commands to the per-kind handler by [`ObjectKind`].
pub struct ObjectManager {
    handlers: HashMap<ObjectKind, Box<dyn ObjectHandler>>,
    events: Vec<ObjectEvent>,
}

impl Model for ObjectManager {
    fn as_any_mut(&mut self) -> &mut dyn Any {
        self
    }
}

impl ObjectManager {
    pub fn new(interface: NativeInterfaceRef) -> Self {
        let mut handlers = HashMap::new();
        for factory in inventory::iter::<ObjectHandlerFactory> {
            handlers.insert(factory.kind, (factory.make)(interface));
        }
        ObjectManager {
            handlers,
            events: Vec::new(),
        }
    }

    /// Create an object. `model_id` is `Some` on redo/undo-restore so it keeps
    /// its stable id. Returns the allocated id, or `None` if creation failed.
    pub fn add(
        &mut self,
        kind: ObjectKind,
        data: &ObjectData,
        model_id: Option<i32>,
    ) -> Option<i32> {
        let result = self.handler_mut(&kind)?.add(data, model_id);
        self.collect_events(kind);
        if result.is_none() {
            log::warn!("objects: add {kind:?} produced no object");
        }
        result
    }

    /// Remove the object, returning its data so undo can re-add it.
    pub fn remove(&mut self, kind: ObjectKind, model_id: i32) -> Option<ObjectData> {
        let removed = self.handler_mut(&kind)?.remove(model_id);
        self.collect_events(kind);
        removed
    }

    /// Read save-shaped object data (omits `dir`, redundant with `rot`).
    pub fn get(&self, kind: ObjectKind, model_id: i32) -> Option<ObjectData> {
        let mut data = self.get_full(kind, model_id)?;
        data.fields.retain(|field| field.name != "dir");
        Some(data)
    }

    /// Read every modeled field, including ones the saved form omits.
    pub fn get_full(&self, kind: ObjectKind, model_id: i32) -> Option<ObjectData> {
        self.handler(&kind)?.read(model_id)
    }

    pub fn set_field(&mut self, kind: ObjectKind, model_id: i32, name: &str, value: &dyn Any) {
        if let Some(handler) = self.handler_mut(&kind) {
            handler.set_field(model_id, name, value);
        }
        self.collect_events(kind);
    }

    pub fn set_fields(&mut self, kind: ObjectKind, model_id: i32, fields: &[FieldValue]) {
        if let Some(handler) = self.handler_mut(&kind) {
            handler.set_fields(model_id, fields);
        }
        self.collect_events(kind);
    }

    pub fn field_value(&self, kind: ObjectKind, model_id: i32, name: &str) -> Option<Box<dyn Any>> {
        self.handler(&kind)?.field_value(model_id, name)
    }

    /// Engine springID for engine-backed objects; `None` for editor-only kinds.
    pub fn spring_id(&self, kind: ObjectKind, model_id: i32) -> Option<i32> {
        self.handler(&kind)?.spring_id(model_id)
    }

    /// The modelID an engine springID maps to; used to select a clicked object.
    pub fn model_id_for_spring(&self, kind: ObjectKind, spring_id: i32) -> Option<i32> {
        self.handler(&kind)?.model_id_for_spring(spring_id)
    }

    /// An object's world position, if it has one.
    pub fn object_pos(&self, kind: ObjectKind, model_id: i32) -> Option<super::object_data::Vec3> {
        let value = self.field_value(kind, model_id, "pos")?;
        value
            .downcast::<super::object_data::Vec3>()
            .ok()
            .map(|v| *v)
    }

    /// One field's current value as JSON, for the property editor to render.
    pub fn field_json(
        &self,
        kind: ObjectKind,
        model_id: i32,
        name: &str,
    ) -> Option<serde_json::Value> {
        let descriptor = self.descriptor(kind, name)?;
        let value = self.field_value(kind, model_id, name)?;
        super::super::codec::field_to_json(descriptor.value_type, &*value)
    }

    pub fn latest_model_id(&self, kind: ObjectKind) -> i32 {
        self.handler(&kind)
            .map(|handler| handler.latest_model_id())
            .unwrap_or(0)
    }

    pub fn field_descriptors(&self, kind: ObjectKind) -> Option<Vec<ObjectFieldDescriptor>> {
        Some(self.handler(&kind)?.descriptors())
    }

    pub fn descriptor(&self, kind: ObjectKind, name: &str) -> Option<ObjectFieldDescriptor> {
        self.handler(&kind)?.descriptor(name)
    }

    pub fn drain_events(&mut self) -> Vec<ObjectEvent> {
        std::mem::take(&mut self.events)
    }

    fn collect_events(&mut self, kind: ObjectKind) {
        let events = self
            .handler_mut(&kind)
            .map(ObjectHandler::drain_events)
            .unwrap_or_default();
        self.events.extend(events);
    }

    /// Full object data as JSON (all modeled fields), for clipboard / export.
    pub fn object_json(&self, kind: ObjectKind, model_id: i32) -> Option<serde_json::Value> {
        let handler = self.handler(&kind)?;
        let data = handler.read(model_id)?;
        Some(crate::sbc::objects::codec::object_to_json(&data))
    }

    /// Every existing model id of this kind, for select-all and clipboard.
    pub fn all_model_ids(&self, kind: ObjectKind) -> Vec<i32> {
        let Some(handler) = self.handler(&kind) else {
            return Vec::new();
        };
        let latest = handler.latest_model_id();
        (1..=latest).filter(|&id| handler.exists(id)).collect()
    }

    /// The defName of an object, if it has one (units, features).
    pub fn def_name(&self, kind: ObjectKind, model_id: i32) -> Option<String> {
        let handler = self.handler(&kind)?;
        match handler.def(model_id)? {
            super::object_data::DefRef::Name(s) => Some(s),
            super::object_data::DefRef::Id(_) => {
                // Fall back to the defName field if the def is an id.
                self.field_json(kind, model_id, "defName")
                    .and_then(|v| v.as_str().map(String::from))
            }
        }
    }

    fn handler(&self, kind: &ObjectKind) -> Option<&(dyn ObjectHandler + '_)> {
        self.handlers.get(kind).map(|handler| handler.as_ref())
    }

    fn handler_mut(&mut self, kind: &ObjectKind) -> Option<&mut (dyn ObjectHandler + '_)> {
        match self.handlers.get_mut(kind) {
            Some(handler) => Some(handler.as_mut()),
            None => None,
        }
    }
}
