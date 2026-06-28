use std::any::Any;
use std::collections::HashMap;

use crate::sbc::objects::model::field_descriptor::ObjectFieldDescriptor;
use crate::sbc::objects::model::object_data::Vec3;
use crate::sbc::objects::model::object_event::{ObjectEvent, ObjectEventObject};
use crate::sbc::objects::model::object_handler::ObjectHandler;
use crate::sbc::objects::model::object_kind::ObjectKind;
use crate::sbc::objects::model::object_value::{FieldValue, ObjectData};

use super::fields;

/// Areas are axis-aligned map rects, not engine objects, so they live entirely
/// here: an id → rect map with its own id allocator (the areaID is the stable id,
/// there is no engine springID). The rect is `[x1, z1, x2, z2]`.
#[derive(Default)]
pub struct AreaModel {
    pub(super) areas: HashMap<i32, [f32; 4]>,
    id_count: i32,
    events: Vec<ObjectEvent>,
}

impl AreaModel {
    pub fn new() -> Self {
        Self::default()
    }

    pub fn rect_around(cx: f32, cz: f32, w: f32, h: f32) -> [f32; 4] {
        [cx - w / 2.0, cz - h / 2.0, cx + w / 2.0, cz + h / 2.0]
    }

    fn add_rect(&mut self, rect: [f32; 4], model_id: Option<i32>) -> i32 {
        let id = model_id.unwrap_or(self.id_count + 1);
        if id > self.id_count {
            self.id_count = id;
        }
        self.areas.insert(id, rect);
        id
    }

    fn push_updated(&mut self, model_id: i32, name: &'static str) {
        let Some(descriptor) = self.descriptor(name) else {
            return;
        };
        if let Some(value) = self.field_value(model_id, name) {
            self.events.push(ObjectEvent::Updated {
                kind: ObjectKind::Area,
                object_id: model_id,
                name: descriptor.name,
                value_type: descriptor.value_type,
                value,
            });
        }
    }
}

impl ObjectHandler for AreaModel {
    fn add(&mut self, data: &ObjectData, model_id: Option<i32>) -> Option<i32> {
        let pos = data.field_ref::<Vec3>("pos")?;
        let size = data.field_ref::<Vec3>("size")?;
        let rect = Self::rect_around(pos.x, pos.z, size.x, size.z);
        let id = self.add_rect(rect, model_id.or(data.model_id));
        if let Some(data) = self.read(id) {
            self.events.push(ObjectEvent::Added {
                kind: ObjectKind::Area,
                object_id: id,
                object: ObjectEventObject::Data(data),
            });
        }
        Some(id)
    }

    fn remove(&mut self, model_id: i32) -> Option<ObjectData> {
        let data = self.read(model_id)?;
        self.areas.remove(&model_id)?;
        self.events.push(ObjectEvent::Removed {
            kind: ObjectKind::Area,
            object_id: model_id,
        });
        Some(data)
    }

    fn set_field(&mut self, model_id: i32, name: &str, value: &dyn Any) {
        if !self.areas.contains_key(&model_id) {
            log::warn!("objects: area set_field requested unknown modelID {model_id}");
            return;
        }
        if let Some(entry) = fields::by_name(name) {
            (entry.set)(self, model_id, value);
            self.push_updated(model_id, entry.descriptor.name);
        }
    }

    fn set_fields(&mut self, model_id: i32, fields: &[FieldValue]) {
        if !self.areas.contains_key(&model_id) {
            log::warn!("objects: area set_fields requested unknown modelID {model_id}");
            return;
        }
        for field in fields {
            if let Some(entry) = fields::by_name(field.name) {
                (entry.set)(self, model_id, &*field.value);
                self.push_updated(model_id, entry.descriptor.name);
            }
        }
    }

    fn field_value(&self, model_id: i32, name: &str) -> Option<Box<dyn Any>> {
        let entry = fields::by_name(name)?;
        (entry.get)(self, model_id)
    }

    fn descriptors(&self) -> Vec<ObjectFieldDescriptor> {
        fields::descriptors()
    }

    fn exists(&self, model_id: i32) -> bool {
        self.areas.contains_key(&model_id)
    }

    fn latest_model_id(&self) -> i32 {
        self.id_count
    }

    fn drain_events(&mut self) -> Vec<ObjectEvent> {
        std::mem::take(&mut self.events)
    }
}

pub(super) fn rect_with_center(rect: [f32; 4], cx: f32, cz: f32) -> [f32; 4] {
    let (w, h) = area_extent(rect);
    AreaModel::rect_around(cx, cz, w, h)
}

pub(super) fn rect_with_size(rect: [f32; 4], w: f32, h: f32) -> [f32; 4] {
    let (cx, cz) = area_center(rect);
    AreaModel::rect_around(cx, cz, w, h)
}

pub(super) fn area_center(rect: [f32; 4]) -> (f32, f32) {
    ((rect[0] + rect[2]) / 2.0, (rect[1] + rect[3]) / 2.0)
}

pub(super) fn area_extent(rect: [f32; 4]) -> (f32, f32) {
    ((rect[2] - rect[0]).abs(), (rect[3] - rect[1]).abs())
}
