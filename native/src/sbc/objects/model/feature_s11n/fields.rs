use std::collections::HashMap;

use spring_native::prelude::sys;

use crate::sbc::objects::model::field::{FieldEntry, TypedField};
use crate::sbc::objects::model::field_descriptor::{
    FieldRange, FieldValueType, ObjectFieldDescriptor,
};
use crate::sbc::objects::model::object_data::{
    Blocking, Collision, FeatureResources, MidAimPos, RadiusHeight, RuleValue, Vec3,
};

use super::model::FeatureModel;
use super::rules::{read_rules, write_rules};

inventory::collect!(FieldEntry<FeatureModel>);

pub(super) fn by_name(name: &str) -> Option<&'static FieldEntry<FeatureModel>> {
    inventory::iter::<FieldEntry<FeatureModel>>
        .into_iter()
        .find(|entry| entry.descriptor.name == name)
}

pub(super) fn descriptors() -> Vec<ObjectFieldDescriptor> {
    inventory::iter::<FieldEntry<FeatureModel>>
        .into_iter()
        .map(|entry| entry.descriptor)
        .collect()
}

struct Pos;
impl TypedField<FeatureModel> for Pos {
    type Value = Vec3;
    const DESCRIPTOR: ObjectFieldDescriptor = ObjectFieldDescriptor {
        name: "pos",
        value_type: FieldValueType::Vec3,
        range: None,
        description: "World position.",
    };
    fn get(s: &FeatureModel, id: i32) -> Option<Vec3> {
        Some(s.interface.features().get_feature_position(id).ok()?.into())
    }
    fn set(s: &mut FeatureModel, id: i32, pos: &Vec3) {
        let _ = s
            .interface
            .synced_ctrl()
            .feature()
            .set_feature_position(id, (*pos).into(), false);
    }
}
inventory::submit! { FieldEntry::of::<Pos>() }

struct Rot;
impl TypedField<FeatureModel> for Rot {
    type Value = Vec3;
    const DESCRIPTOR: ObjectFieldDescriptor = ObjectFieldDescriptor {
        name: "rot",
        value_type: FieldValueType::Vec3,
        range: None,
        description: "Euler rotation in radians.",
    };
    fn get(s: &FeatureModel, id: i32) -> Option<Vec3> {
        let rot = s.interface.features().get_feature_rotation(id).ok()?;
        Some(Vec3 {
            x: rot.pitch,
            y: rot.yaw,
            z: rot.roll,
        })
    }
    fn set(s: &mut FeatureModel, id: i32, rot: &Vec3) {
        s.apply_rotation(id, *rot);
    }
}
inventory::submit! { FieldEntry::of::<Rot>() }

struct Vel;
impl TypedField<FeatureModel> for Vel {
    type Value = Vec3;
    const DESCRIPTOR: ObjectFieldDescriptor = ObjectFieldDescriptor {
        name: "vel",
        value_type: FieldValueType::Vec3,
        range: None,
        description: "World velocity.",
    };
    fn get(s: &FeatureModel, id: i32) -> Option<Vec3> {
        Some(s.interface.features().get_feature_velocity(id).ok()?.into())
    }
    fn set(s: &mut FeatureModel, id: i32, vel: &Vec3) {
        let _ = s
            .interface
            .synced_ctrl()
            .feature()
            .set_feature_velocity(id, (*vel).into());
    }
}
inventory::submit! { FieldEntry::of::<Vel>() }

struct Dir;
impl TypedField<FeatureModel> for Dir {
    type Value = Vec3;
    const DESCRIPTOR: ObjectFieldDescriptor = ObjectFieldDescriptor {
        name: "dir",
        value_type: FieldValueType::Direction,
        range: None,
        description: "Facing direction vector.",
    };
    fn get(s: &FeatureModel, id: i32) -> Option<Vec3> {
        Some(
            s.interface
                .features()
                .get_feature_direction(id)
                .ok()?
                .into(),
        )
    }
    fn set(s: &mut FeatureModel, id: i32, dir: &Vec3) {
        let right = sys::Float3 {
            x: -dir.z,
            y: 0.0,
            z: dir.x,
        };
        let _ = s
            .interface
            .synced_ctrl()
            .feature()
            .set_feature_direction(id, (*dir).into(), right);
    }
}
inventory::submit! { FieldEntry::of::<Dir>() }

struct Mass;
impl TypedField<FeatureModel> for Mass {
    type Value = f32;
    const DESCRIPTOR: ObjectFieldDescriptor = ObjectFieldDescriptor {
        name: "mass",
        value_type: FieldValueType::Float,
        range: Some(FieldRange::at_least(0.0)),
        description: "Feature mass used by physics and reclaim interactions.",
    };
    fn get(s: &FeatureModel, id: i32) -> Option<f32> {
        s.interface.features().get_feature_mass(id).ok()
    }
    fn set(s: &mut FeatureModel, id: i32, mass: &f32) {
        let _ = s
            .interface
            .synced_ctrl()
            .feature()
            .set_feature_mass(id, *mass);
    }
}
inventory::submit! { FieldEntry::of::<Mass>() }

struct MidAim;
impl TypedField<FeatureModel> for MidAim {
    type Value = MidAimPos;
    const DESCRIPTOR: ObjectFieldDescriptor = ObjectFieldDescriptor {
        name: "midAimPos",
        value_type: FieldValueType::Object("MidAimPos"),
        range: None,
        description: "Position-relative mid and aim offsets.",
    };
    fn get(s: &FeatureModel, id: i32) -> Option<MidAimPos> {
        let p = s.interface.features().get_feature_position_ext(id).ok()?;
        let pos: Vec3 = p.position.into();
        let mid: Vec3 = p.midPosition.into();
        let aim: Vec3 = p.aimPosition.into();
        Some(MidAimPos {
            mid: Vec3 {
                x: mid.x - pos.x,
                y: mid.y - pos.y,
                z: mid.z - pos.z,
            },
            aim: Vec3 {
                x: aim.x - pos.x,
                y: aim.y - pos.y,
                z: aim.z - pos.z,
            },
        })
    }
    fn set(s: &mut FeatureModel, id: i32, mid_aim: &MidAimPos) {
        let _ = s
            .interface
            .synced_ctrl()
            .feature()
            .set_feature_mid_and_aim_pos(id, mid_aim.mid.into(), mid_aim.aim.into(), true);
    }
}
inventory::submit! { FieldEntry::of::<MidAim>() }

struct BlockingField;
impl TypedField<FeatureModel> for BlockingField {
    type Value = Blocking;
    const DESCRIPTOR: ObjectFieldDescriptor = ObjectFieldDescriptor {
        name: "blocking",
        value_type: FieldValueType::Object("Blocking"),
        range: None,
        description: "Collision/blocking flags.",
    };
    fn get(s: &FeatureModel, id: i32) -> Option<Blocking> {
        let b = s.interface.features().get_feature_blocking(id).ok()?;
        Some(Blocking {
            is_blocking: b.isBlocking,
            is_solid_object_collidable: b.isSolidObjectCollidable,
            is_projectile_collidable: b.isProjectileCollidable,
            is_ray_segment_collidable: b.isRaySegmentCollidable,
            crushable: b.crushable,
            block_enemy_pushing: b.blockEnemyPushing,
            block_height_changes: b.blockHeightChanges,
        })
    }
    fn set(s: &mut FeatureModel, id: i32, b: &Blocking) {
        let _ = s.interface.synced_ctrl().feature().set_feature_blocking(
            id,
            b.is_blocking,
            b.is_solid_object_collidable,
            b.is_projectile_collidable,
            b.is_ray_segment_collidable,
            b.crushable,
            b.block_enemy_pushing,
            b.block_height_changes,
        );
    }
}
inventory::submit! { FieldEntry::of::<BlockingField>() }

struct RadiusHeightField;
impl TypedField<FeatureModel> for RadiusHeightField {
    type Value = RadiusHeight;
    const DESCRIPTOR: ObjectFieldDescriptor = ObjectFieldDescriptor {
        name: "radiusHeight",
        value_type: FieldValueType::Object("RadiusHeight"),
        range: Some(FieldRange::at_least(0.0)),
        description: "Feature selection/collision radius and height.",
    };
    fn get(s: &FeatureModel, id: i32) -> Option<RadiusHeight> {
        let info = s.interface.features();
        Some(RadiusHeight {
            radius: info.get_feature_radius(id).ok()?,
            height: info.get_feature_height(id).ok()?,
        })
    }
    fn set(s: &mut FeatureModel, id: i32, rh: &RadiusHeight) {
        let _ = s
            .interface
            .synced_ctrl()
            .feature()
            .set_feature_radius_and_height(id, rh.radius, rh.height);
    }
}
inventory::submit! { FieldEntry::of::<RadiusHeightField>() }

struct CollisionField;
impl TypedField<FeatureModel> for CollisionField {
    type Value = Collision;
    const DESCRIPTOR: ObjectFieldDescriptor = ObjectFieldDescriptor {
        name: "collision",
        value_type: FieldValueType::Object("Collision"),
        range: None,
        description: "Collision volume scale, offset, type, test type, and axis.",
    };
    fn get(s: &FeatureModel, id: i32) -> Option<Collision> {
        let c = s
            .interface
            .features()
            .get_feature_collision_volume_data(id)
            .ok()?;
        Some(Collision {
            scale_x: c.scaleX,
            scale_y: c.scaleY,
            scale_z: c.scaleZ,
            offset_x: c.offsetX,
            offset_y: c.offsetY,
            offset_z: c.offsetZ,
            v_type: c.volumeType,
            test_type: c.testType,
            axis: c.primaryAxis,
        })
    }
    fn set(s: &mut FeatureModel, id: i32, c: &Collision) {
        let _ = s
            .interface
            .synced_ctrl()
            .feature()
            .set_feature_collision_volume_data(
                id,
                sys::Float3 {
                    x: c.scale_x,
                    y: c.scale_y,
                    z: c.scale_z,
                },
                sys::Float3 {
                    x: c.offset_x,
                    y: c.offset_y,
                    z: c.offset_z,
                },
                c.v_type,
                c.test_type,
                c.axis,
            );
    }
}
inventory::submit! { FieldEntry::of::<CollisionField>() }

struct Team;
impl TypedField<FeatureModel> for Team {
    type Value = i32;
    const DESCRIPTOR: ObjectFieldDescriptor = ObjectFieldDescriptor {
        name: "team",
        value_type: FieldValueType::Int,
        range: Some(FieldRange::at_least(0.0)),
        description: "Owning team.",
    };
    fn get(s: &FeatureModel, id: i32) -> Option<i32> {
        s.interface.features().get_feature_team(id).ok()
    }
    fn set(s: &mut FeatureModel, id: i32, team: &i32) {
        if s.interface.features().get_feature_team(id).ok() != Some(*team) {
            let _ = s
                .interface
                .synced_ctrl()
                .feature()
                .transfer_feature(id, *team);
        }
    }
}
inventory::submit! { FieldEntry::of::<Team>() }

struct Health;
impl TypedField<FeatureModel> for Health {
    type Value = f32;
    const DESCRIPTOR: ObjectFieldDescriptor = ObjectFieldDescriptor {
        name: "health",
        value_type: FieldValueType::Float,
        range: Some(FieldRange::at_least(0.0)),
        description: "Current feature health.",
    };
    fn get(s: &FeatureModel, id: i32) -> Option<f32> {
        Some(s.interface.features().get_feature_health(id).ok()?.health)
    }
    fn set(s: &mut FeatureModel, id: i32, health: &f32) {
        let _ = s
            .interface
            .synced_ctrl()
            .feature()
            .set_feature_health(id, *health, false);
    }
}
inventory::submit! { FieldEntry::of::<Health>() }

struct Resources;
impl TypedField<FeatureModel> for Resources {
    type Value = FeatureResources;
    const DESCRIPTOR: ObjectFieldDescriptor = ObjectFieldDescriptor {
        name: "resources",
        value_type: FieldValueType::Object("FeatureResources"),
        range: Some(FieldRange::between(0.0, 1.0)),
        description: "Stored resources and reclaim progress.",
    };
    fn get(s: &FeatureModel, id: i32) -> Option<FeatureResources> {
        let r = s.interface.features().get_feature_resources(id).ok()?;
        Some(FeatureResources {
            metal: Some(r.metal),
            energy: Some(r.energy),
            metal_max: Some(r.defMetal),
            energy_max: Some(r.defEnergy),
            reclaim_left: Some(r.reclaimLeft),
            reclaim_time: Some(r.reclaimTime),
        })
    }
    fn set(s: &mut FeatureModel, id: i32, r: &FeatureResources) {
        // The setter takes the full set; the editor may send only {metal,
        // energy}, so read the current values to fill the rest.
        let cur = s.interface.features().get_feature_resources(id).ok();
        let metal = r.metal.or(cur.map(|c| c.metal)).unwrap_or(0.0);
        let energy = r.energy.or(cur.map(|c| c.energy)).unwrap_or(0.0);
        let metal_max = r.metal_max.or(cur.map(|c| c.defMetal)).unwrap_or(metal);
        let energy_max = r.energy_max.or(cur.map(|c| c.defEnergy)).unwrap_or(energy);
        let reclaim_left = r.reclaim_left.or(cur.map(|c| c.reclaimLeft)).unwrap_or(1.0);
        let reclaim_time = r.reclaim_time.or(cur.map(|c| c.reclaimTime)).unwrap_or(0.0);
        let _ = s.interface.synced_ctrl().feature().set_feature_resources(
            id,
            metal,
            energy,
            reclaim_time,
            reclaim_left,
            metal_max,
            energy_max,
        );
    }
}
inventory::submit! { FieldEntry::of::<Resources>() }

struct Rules;
impl TypedField<FeatureModel> for Rules {
    type Value = HashMap<String, RuleValue>;
    const DESCRIPTOR: ObjectFieldDescriptor = ObjectFieldDescriptor {
        name: "rules",
        value_type: FieldValueType::RulesMap,
        range: None,
        description: "Feature rules params keyed by param name.",
    };
    fn get(s: &FeatureModel, id: i32) -> Option<HashMap<String, RuleValue>> {
        read_rules(&s.interface, id)
    }
    fn set(s: &mut FeatureModel, id: i32, rules: &HashMap<String, RuleValue>) {
        write_rules(&s.interface, id, rules);
    }
}
inventory::submit! { FieldEntry::of::<Rules>() }
