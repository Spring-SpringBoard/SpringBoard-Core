use spring_native::prelude::sys;

use crate::sbc::objects::model::field::{FieldEntry, TypedField};
use crate::sbc::objects::model::field_descriptor::{
    FieldRange, FieldValueType, ObjectFieldDescriptor,
};
use crate::sbc::objects::model::object_data::{Blocking, Collision, MidAimPos, RadiusHeight, Vec3};

use super::model::UnitModel;

mod runtime;

inventory::collect!(FieldEntry<UnitModel>);

pub(super) fn by_name(name: &str) -> Option<&'static FieldEntry<UnitModel>> {
    inventory::iter::<FieldEntry<UnitModel>>
        .into_iter()
        .find(|entry| entry.descriptor.name == name)
}

pub(super) fn descriptors() -> Vec<ObjectFieldDescriptor> {
    inventory::iter::<FieldEntry<UnitModel>>
        .into_iter()
        .map(|entry| entry.descriptor)
        .collect()
}

struct Pos;
impl TypedField<UnitModel> for Pos {
    type Value = Vec3;
    const DESCRIPTOR: ObjectFieldDescriptor = ObjectFieldDescriptor {
        name: "pos",
        value_type: FieldValueType::Vec3,
        range: None,
        description: "World position.",
    };
    fn get(s: &UnitModel, id: i32) -> Option<Vec3> {
        Some(
            s.interface
                .units_info()
                .get_unit_position(id, spring_native::GetUnitPositionOptions::default())
                .ok()?
                .into(),
        )
    }
    fn set(s: &mut UnitModel, id: i32, pos: &Vec3) {
        let _ = s
            .interface
            .synced_ctrl()
            .unit()
            .set_unit_position(id, (*pos).into());
    }
}
inventory::submit! { FieldEntry::of::<Pos>() }

struct Rot;
impl TypedField<UnitModel> for Rot {
    type Value = Vec3;
    const DESCRIPTOR: ObjectFieldDescriptor = ObjectFieldDescriptor {
        name: "rot",
        value_type: FieldValueType::Vec3,
        range: None,
        description: "Euler rotation in radians.",
    };
    fn get(s: &UnitModel, id: i32) -> Option<Vec3> {
        let rot = s.interface.units_info().get_unit_rotation(id).ok()?;
        Some(Vec3 {
            x: rot.pitch,
            y: rot.yaw,
            z: rot.roll,
        })
    }
    fn set(s: &mut UnitModel, id: i32, rot: &Vec3) {
        s.apply_rotation(id, *rot);
    }
}
inventory::submit! { FieldEntry::of::<Rot>() }

struct Vel;
impl TypedField<UnitModel> for Vel {
    type Value = Vec3;
    const DESCRIPTOR: ObjectFieldDescriptor = ObjectFieldDescriptor {
        name: "vel",
        value_type: FieldValueType::Vec3,
        range: None,
        description: "World velocity.",
    };
    fn get(s: &UnitModel, id: i32) -> Option<Vec3> {
        Some(s.interface.units_info().get_unit_velocity(id).ok()?.into())
    }
    fn set(s: &mut UnitModel, id: i32, vel: &Vec3) {
        let _ = s
            .interface
            .synced_ctrl()
            .unit()
            .set_unit_velocity(id, (*vel).into());
    }
}
inventory::submit! { FieldEntry::of::<Vel>() }

struct Dir;
impl TypedField<UnitModel> for Dir {
    type Value = Vec3;
    const DESCRIPTOR: ObjectFieldDescriptor = ObjectFieldDescriptor {
        name: "dir",
        value_type: FieldValueType::Direction,
        range: None,
        description: "Facing direction vector.",
    };
    fn get(s: &UnitModel, id: i32) -> Option<Vec3> {
        Some(s.interface.units_info().get_unit_direction(id).ok()?.into())
    }
    fn set(s: &mut UnitModel, id: i32, dir: &Vec3) {
        let right = sys::Float3 {
            x: -dir.z,
            y: 0.0,
            z: dir.x,
        };
        let _ = s
            .interface
            .synced_ctrl()
            .unit()
            .set_unit_direction(id, (*dir).into(), right);
    }
}
inventory::submit! { FieldEntry::of::<Dir>() }

struct Mass;
impl TypedField<UnitModel> for Mass {
    type Value = f32;
    const DESCRIPTOR: ObjectFieldDescriptor = ObjectFieldDescriptor {
        name: "mass",
        value_type: FieldValueType::Float,
        range: Some(FieldRange::at_least(0.0)),
        description: "Unit mass.",
    };
    fn get(s: &UnitModel, id: i32) -> Option<f32> {
        s.interface.units_info().get_unit_mass(id).ok()
    }
    fn set(s: &mut UnitModel, id: i32, mass: &f32) {
        let _ = s.interface.synced_ctrl().unit().set_unit_mass(id, *mass);
    }
}
inventory::submit! { FieldEntry::of::<Mass>() }

struct MidAim;
impl TypedField<UnitModel> for MidAim {
    type Value = MidAimPos;
    const DESCRIPTOR: ObjectFieldDescriptor = ObjectFieldDescriptor {
        name: "midAimPos",
        value_type: FieldValueType::Object("MidAimPos"),
        range: None,
        description: "Position-relative mid and aim offsets.",
    };
    fn get(s: &UnitModel, id: i32) -> Option<MidAimPos> {
        let info = s.interface.units_info();
        let pos: Vec3 = info
            .get_unit_position(id, spring_native::GetUnitPositionOptions::default())
            .ok()?
            .into();
        let mid: Vec3 = info
            .get_unit_position(
                id,
                spring_native::GetUnitPositionOptions {
                    mid_pos: true,
                    ..Default::default()
                },
            )
            .ok()?
            .into();
        let aim: Vec3 = info
            .get_unit_position(
                id,
                spring_native::GetUnitPositionOptions {
                    aim_pos: true,
                    ..Default::default()
                },
            )
            .ok()?
            .into();
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
    fn set(s: &mut UnitModel, id: i32, mid_aim: &MidAimPos) {
        let Some(pos) = Pos::get(s, id) else {
            return;
        };
        let mid = vec3_add(&pos, &mid_aim.mid);
        let aim = vec3_add(&pos, &mid_aim.aim);
        let _ = s.interface.synced_ctrl().unit().set_unit_mid_and_aim_pos(
            id,
            mid.into(),
            aim.into(),
            false,
        );
    }
}
inventory::submit! { FieldEntry::of::<MidAim>() }

struct MaxRange;
impl TypedField<UnitModel> for MaxRange {
    type Value = f32;
    const DESCRIPTOR: ObjectFieldDescriptor = ObjectFieldDescriptor {
        name: "maxRange",
        value_type: FieldValueType::Float,
        range: Some(FieldRange::at_least(0.0)),
        description: "Maximum weapon range.",
    };
    fn get(s: &UnitModel, id: i32) -> Option<f32> {
        s.interface.units_weapons().get_unit_max_range(id).ok()
    }
    fn set(s: &mut UnitModel, id: i32, max_range: &f32) {
        let _ = s
            .interface
            .synced_ctrl()
            .unit()
            .set_unit_max_range(id, *max_range);
    }
}
inventory::submit! { FieldEntry::of::<MaxRange>() }

struct BlockingField;
impl TypedField<UnitModel> for BlockingField {
    type Value = Blocking;
    const DESCRIPTOR: ObjectFieldDescriptor = ObjectFieldDescriptor {
        name: "blocking",
        value_type: FieldValueType::Object("Blocking"),
        range: None,
        description: "Collision/blocking flags.",
    };
    fn get(s: &UnitModel, id: i32) -> Option<Blocking> {
        let b = s.interface.units_info().get_unit_blocking(id).ok()?;
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
    fn set(s: &mut UnitModel, id: i32, b: &Blocking) {
        let _ = s.interface.synced_ctrl().unit().set_unit_blocking(
            id,
            spring_native::SetUnitBlockingOptions {
                blocking: b.is_blocking,
                solid_objects: b.is_solid_object_collidable,
                projectiles: b.is_projectile_collidable,
                quad_map_rays: b.is_ray_segment_collidable,
                crushable: b.crushable,
                block_enemy_pushing: b.block_enemy_pushing,
                block_height_changes: b.block_height_changes,
            },
        );
    }
}
inventory::submit! { FieldEntry::of::<BlockingField>() }

struct RadiusHeightField;
impl TypedField<UnitModel> for RadiusHeightField {
    type Value = RadiusHeight;
    const DESCRIPTOR: ObjectFieldDescriptor = ObjectFieldDescriptor {
        name: "radiusHeight",
        value_type: FieldValueType::Object("RadiusHeight"),
        range: Some(FieldRange::at_least(0.0)),
        description: "Unit selection/collision radius and height.",
    };
    fn get(s: &UnitModel, id: i32) -> Option<RadiusHeight> {
        let info = s.interface.units_info();
        Some(RadiusHeight {
            radius: info.get_unit_radius(id).ok()?,
            height: info.get_unit_height(id).ok()?,
        })
    }
    fn set(s: &mut UnitModel, id: i32, rh: &RadiusHeight) {
        let _ = s
            .interface
            .synced_ctrl()
            .unit()
            .set_unit_radius_and_height(id, rh.radius, rh.height);
    }
}
inventory::submit! { FieldEntry::of::<RadiusHeightField>() }

struct CollisionField;
impl TypedField<UnitModel> for CollisionField {
    type Value = Collision;
    const DESCRIPTOR: ObjectFieldDescriptor = ObjectFieldDescriptor {
        name: "collision",
        value_type: FieldValueType::Object("Collision"),
        range: None,
        description: "Collision volume scale, offset, type, test type, and axis.",
    };
    fn get(s: &UnitModel, id: i32) -> Option<Collision> {
        let c = s
            .interface
            .units_info()
            .get_unit_collision_volume_data(id)
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
    fn set(s: &mut UnitModel, id: i32, c: &Collision) {
        let _ = s
            .interface
            .synced_ctrl()
            .unit()
            .set_unit_collision_volume_data(
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

fn vec3_add(a: &Vec3, b: &Vec3) -> Vec3 {
    Vec3 {
        x: a.x + b.x,
        y: a.y + b.y,
        z: a.z + b.z,
    }
}
