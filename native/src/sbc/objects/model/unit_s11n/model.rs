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

/// Synced-side unit state and lifecycle.
pub struct UnitModel {
    pub(super) interface: NativeInterfaceRef,
    pub(super) ids: ModelIdMap,
    events: Vec<ObjectEvent>,
}

impl UnitModel {
    pub fn new(interface: NativeInterfaceRef) -> Self {
        UnitModel {
            interface,
            ids: ModelIdMap::default(),
            events: Vec::new(),
        }
    }

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
                .unit_defs()
                .get_unit_def_idby_name(name)
                .ok()?,
        };
        if def_id < 0 {
            return None;
        }
        let unit_def = sys::DefRef {
            name: std::ptr::null(),
            id: def_id,
        };
        let team = team.unwrap_or(0);
        let spring_id = self
            .interface
            .synced_ctrl()
            .unit()
            .create_unit(unit_def, pos.into(), 0, team, false, false, -1, -1)
            .ok()?;
        if spring_id < 0 {
            return None;
        }
        Some(self.ids.register(spring_id, model_id))
    }

    fn apply_one(&mut self, spring_id: i32, name: &str, value: &dyn Any) {
        if let Some(entry) = fields::by_name(name) {
            (entry.set)(self, spring_id, value);
        }
    }

    /// The health family (health/maxHealth/paralyze/capture/build) must be set
    /// together so the engine's `useAmounts` path sees a coherent value.
    fn apply_health(&self, spring_id: i32, fields: &[FieldValue]) {
        let health = field_f32(fields, "health");
        let max_health = field_f32(fields, "maxHealth");
        let paralyze = field_f32(fields, "paralyze");
        let capture = field_f32(fields, "capture");
        let build = field_f32(fields, "build");
        if health
            .or(max_health)
            .or(paralyze)
            .or(capture)
            .or(build)
            .is_some()
        {
            self.set_health_amounts(spring_id, health, max_health, paralyze, capture, build);
        }
    }

    /// Set any subset of the health family in one engine call, reading current
    /// values for whatever the caller left unset.
    pub(super) fn set_health_amounts(
        &self,
        spring_id: i32,
        health: Option<f32>,
        max_health: Option<f32>,
        paralyze: Option<f32>,
        capture: Option<f32>,
        build: Option<f32>,
    ) {
        let synced = self.interface.synced_ctrl();
        let unit = synced.unit();
        if let Some(max_health) = max_health {
            let _ = unit.set_unit_max_health(spring_id, max_health);
        }

        let has_amounts = paralyze.is_some() || capture.is_some() || build.is_some();
        if !has_amounts {
            if let Some(health) = health {
                let _ = unit.set_unit_health(
                    spring_id,
                    sys::UnitHealthValue {
                        health,
                        capture: 0.0,
                        paralyze: 0.0,
                        build: 0.0,
                        useAmounts: false,
                    },
                );
            }
            return;
        }

        let current = self.interface.units_info().get_unit_health(spring_id).ok();
        let _ = unit.set_unit_health(
            spring_id,
            sys::UnitHealthValue {
                health: health
                    .or_else(|| current.as_ref().map(|h| h.health))
                    .unwrap_or(0.0),
                capture: capture
                    .or_else(|| current.as_ref().map(|h| h.captureProgress))
                    .unwrap_or(0.0),
                paralyze: paralyze
                    .or_else(|| current.as_ref().map(|h| h.paralyzeDamage))
                    .unwrap_or(0.0),
                build: build
                    .or_else(|| current.as_ref().map(|h| h.buildProgress))
                    .unwrap_or(0.0),
                useAmounts: true,
            },
        );
    }

    fn current_rotation(&self, spring_id: i32) -> Option<Vec3> {
        self.interface
            .units_info()
            .get_unit_rotation(spring_id)
            .ok()
            .map(|rot| Vec3 {
                x: rot.pitch,
                y: rot.yaw,
                z: rot.roll,
            })
    }

    pub(super) fn apply_rotation(&self, spring_id: i32, rot: Vec3) {
        let _ = self
            .interface
            .synced_ctrl()
            .unit()
            .set_unit_rotation(spring_id, rot.into());
    }
}

impl ObjectHandler for UnitModel {
    fn add(&mut self, data: &ObjectData, model_id: Option<i32>) -> Option<i32> {
        let def = data.def.as_ref()?;
        let pos = *data.field_ref::<Vec3>("pos")?;
        let team = data.field_ref::<i32>("team").copied();
        let model_id = self.create(def, pos, team, model_id.or(data.model_id))?;

        self.set_fields(model_id, &data.fields);

        let spring_id = self.ids.spring_id(model_id)?;
        self.events.push(ObjectEvent::Added {
            kind: ObjectKind::Unit,
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
            .unit()
            .destroy_unit(spring_id, false, true, -1, false);
        self.ids.unregister(spring_id);
        self.events.push(ObjectEvent::Removed {
            kind: ObjectKind::Unit,
            object_id: spring_id,
        });
        Some(data)
    }

    /// Apply one field, with Lua's workaround for the engine bug where moving a
    /// building resets its facing.
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
    /// are interpreted, so restore them first and apply `midAimPos` last. The
    /// health family still goes through one aggregated call.
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

        self.apply_health(spring_id, fields);

        for field in fields {
            if is_health_field(field.name) || matches!(field.name, "pos" | "rot" | "midAimPos") {
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
            .units_info()
            .get_unit_def_id(spring_id)
            .ok()?;
        Some(DefRef::Name(
            self.interface
                .unit_defs()
                .get_unit_def_name(def_id)
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

fn is_health_field(name: &str) -> bool {
    matches!(
        name,
        "health" | "maxHealth" | "paralyze" | "capture" | "build"
    )
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

fn field_f32(fields: &[FieldValue], name: &str) -> Option<f32> {
    field_dyn(fields, name)?.downcast_ref::<f32>().copied()
}
