use std::any::Any;

use spring_native::prelude::{sys, NativeInterfaceRef};

use crate::sbc::objects::model::field_descriptor::ObjectFieldDescriptor;
use crate::sbc::objects::model::model_id_map::ModelIdMap;
use crate::sbc::objects::model::object_data::{DefRef, Vec3};
use crate::sbc::objects::model::object_event::{ObjectEvent, ObjectEventObject};
use crate::sbc::objects::model::object_handler::ObjectHandler;
use crate::sbc::objects::model::object_kind::ObjectKind;
use crate::sbc::objects::model::object_value::{FieldValue, ObjectData};

use super::fields;

/// Synced-side feature state and lifecycle.
pub struct FeatureModel {
    pub(super) interface: NativeInterfaceRef,
    ids: ModelIdMap,
    events: Vec<ObjectEvent>,
}

impl FeatureModel {
    pub fn new(interface: NativeInterfaceRef) -> Self {
        FeatureModel {
            interface,
            ids: ModelIdMap::default(),
            events: Vec::new(),
        }
    }

    pub(super) fn apply_rotation(&self, spring_id: i32, rot: Vec3) {
        let _ = self
            .interface
            .synced_ctrl()
            .feature()
            .set_feature_rotation(spring_id, rot.into());
    }

    /// Create a feature and register its id. Fields are applied separately.
    fn create(
        &mut self,
        def: &DefRef,
        pos: Vec3,
        team: Option<i32>,
        model_id: Option<i32>,
    ) -> Option<i32> {
        let def_id = match def {
            DefRef::Id(id) => *id,
            DefRef::Name(name) => self
                .interface
                .feature_defs()
                .get_feature_def_idby_name(name)
                .ok()?,
        };
        if def_id < 0 {
            return None;
        }
        let feature_def = sys::DefRef {
            name: std::ptr::null(),
            id: def_id,
        };
        let team = team.unwrap_or(0);
        let spring_id = self
            .interface
            .synced_ctrl()
            .feature()
            .create_feature(feature_def, pos.into(), 0, team, -1)
            .ok()?;
        if spring_id < 0 {
            return None;
        }

        // Lua `CreateObject` enables MoveCtrl for off-ground features before
        // setting fields; keep the same order here.
        let ground = self
            .interface
            .terrain()
            .get_ground_height(pos.x, pos.z)
            .unwrap_or(pos.y);
        if (ground - pos.y).abs() >= 0.1 {
            let zero = sys::Float3 {
                x: 0.0,
                y: 0.0,
                z: 0.0,
            };
            let _ = self
                .interface
                .synced_ctrl()
                .feature()
                .set_feature_move_ctrl(spring_id, true, zero, zero, zero);
        }

        Some(self.ids.register(spring_id, model_id))
    }

    fn apply_one(&mut self, spring_id: i32, name: &str, value: &dyn Any) {
        if let Some(entry) = fields::by_name(name) {
            (entry.set)(self, spring_id, value);
        }
    }

    fn current_rotation(&self, spring_id: i32) -> Option<Vec3> {
        self.interface
            .features()
            .get_feature_rotation(spring_id)
            .ok()
            .map(|rot| Vec3 {
                x: rot.pitch,
                y: rot.yaw,
                z: rot.roll,
            })
    }
}

impl ObjectHandler for FeatureModel {
    fn add(&mut self, data: &ObjectData, model_id: Option<i32>) -> Option<i32> {
        let def = data.def.as_ref()?;
        let pos = *data.field_ref::<Vec3>("pos")?;
        let team = data.field_ref::<i32>("team").copied();
        let model_id = self.create(def, pos, team, model_id.or(data.model_id))?;

        self.set_fields(model_id, &data.fields);

        let spring_id = self.ids.spring_id(model_id)?;
        self.events.push(ObjectEvent::Added {
            kind: ObjectKind::Feature,
            object_id: spring_id,
            object: ObjectEventObject::ModelId(model_id),
        });
        Some(model_id)
    }

    fn remove(&mut self, model_id: i32) -> Option<ObjectData> {
        let data = self.read(model_id)?;
        let spring_id = self.ids.spring_id(model_id)?;
        let _ = self
            .interface
            .synced_ctrl()
            .feature()
            .destroy_feature(spring_id);
        self.ids.unregister(spring_id);
        self.events.push(ObjectEvent::Removed {
            kind: ObjectKind::Feature,
            object_id: spring_id,
        });
        Some(data)
    }

    /// Apply one field, with Lua's workaround for the engine bug where moving an
    /// object resets its facing.
    fn set_field(&mut self, model_id: i32, name: &str, value: &dyn Any) {
        let Some(spring_id) = self.ids.spring_id(model_id) else {
            return;
        };
        let restore_rot = (name == "pos")
            .then(|| self.current_rotation(spring_id))
            .flatten();
        self.apply_one(spring_id, name, value);
        if let Some(rot) = restore_rot {
            self.apply_rotation(spring_id, rot);
        }
    }

    /// Apply a set of fields. Rotation and position affect how mid/aim offsets
    /// are interpreted, so restore them first and apply `midAimPos` last.
    fn set_fields(&mut self, model_id: i32, fields: &[FieldValue]) {
        let Some(spring_id) = self.ids.spring_id(model_id) else {
            return;
        };
        let restore_rot = if fields.iter().any(|field| field.name == "pos") {
            field_vec3(fields, "rot").or_else(|| self.current_rotation(spring_id))
        } else {
            None
        };

        if let Some(rot) = field_dyn(fields, "rot") {
            self.apply_one(spring_id, "rot", rot);
        }
        if let Some(pos) = field_dyn(fields, "pos") {
            self.apply_one(spring_id, "pos", pos);
        }

        if let Some(rot) = restore_rot {
            self.apply_rotation(spring_id, rot);
        }

        for field in fields {
            if matches!(field.name, "pos" | "rot" | "midAimPos") {
                continue;
            }
            self.apply_one(spring_id, field.name, &*field.value);
        }
        if let Some(mid_aim) = field_dyn(fields, "midAimPos") {
            self.apply_one(spring_id, "midAimPos", mid_aim);
        }
    }

    fn field_value(&self, model_id: i32, name: &str) -> Option<Box<dyn Any>> {
        let spring_id = self.ids.spring_id(model_id)?;
        let entry = fields::by_name(name)?;
        (entry.get)(self, spring_id)
    }

    fn descriptors(&self) -> Vec<ObjectFieldDescriptor> {
        fields::descriptors()
    }

    fn exists(&self, model_id: i32) -> bool {
        self.ids.spring_id(model_id).is_some()
    }

    fn latest_model_id(&self) -> i32 {
        self.ids.latest_model_id()
    }

    fn drain_events(&mut self) -> Vec<ObjectEvent> {
        std::mem::take(&mut self.events)
    }

    fn def(&self, model_id: i32) -> Option<DefRef> {
        let spring_id = self.ids.spring_id(model_id)?;
        let def_id = self
            .interface
            .features()
            .get_feature_def_id(spring_id)
            .ok()?;
        Some(DefRef::Name(
            self.interface
                .feature_defs()
                .get_feature_def_name(def_id)
                .ok()??,
        ))
    }

    fn spring_id(&self, model_id: i32) -> Option<i32> {
        self.ids.spring_id(model_id)
    }

    fn model_id_for_spring(&self, spring_id: i32) -> Option<i32> {
        self.ids.model_id(spring_id)
    }
}

fn field_dyn<'a>(fields: &'a [FieldValue], name: &str) -> Option<&'a dyn Any> {
    fields
        .iter()
        .find(|field| field.name == name)
        .map(|field| &*field.value)
}

fn field_vec3(fields: &[FieldValue], name: &str) -> Option<Vec3> {
    field_dyn(fields, name)?.downcast_ref::<Vec3>().copied()
}
