use std::collections::HashMap;

use spring_native::prelude::sys;

use crate::sbc::objects::model::field::{FieldEntry, TypedField};
use crate::sbc::objects::model::field_descriptor::{
    FieldRange, FieldValueType, ObjectFieldDescriptor,
};
use crate::sbc::objects::model::object_data::{
    Armored, Blocking, Collision, HarvestStorage, MidAimPos, RadiusHeight, RuleValue, UnitCommand,
    UnitResources, UnitStates, Vec3,
};

use super::commands::{read_commands, write_commands};
use super::model::UnitModel;
use super::rules::{read_rules, write_rules};
use super::states::{read_states, write_states};

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

struct Team;
impl TypedField<UnitModel> for Team {
    type Value = i32;
    const DESCRIPTOR: ObjectFieldDescriptor = ObjectFieldDescriptor {
        name: "team",
        value_type: FieldValueType::Int,
        range: Some(FieldRange::at_least(0.0)),
        description: "Owning team.",
    };
    fn get(s: &UnitModel, id: i32) -> Option<i32> {
        s.interface.units_info().get_unit_team(id).ok()
    }
    fn set(s: &mut UnitModel, id: i32, team: &i32) {
        if s.interface.units_info().get_unit_team(id).ok() != Some(*team) {
            let _ = s
                .interface
                .synced_ctrl()
                .unit()
                .transfer_unit(id, *team, false, false);
        }
    }
}
inventory::submit! { FieldEntry::of::<Team>() }

struct Health;
impl TypedField<UnitModel> for Health {
    type Value = f32;
    const DESCRIPTOR: ObjectFieldDescriptor = ObjectFieldDescriptor {
        name: "health",
        value_type: FieldValueType::Float,
        range: Some(FieldRange::at_least(0.0)),
        description: "Current unit health.",
    };
    fn get(s: &UnitModel, id: i32) -> Option<f32> {
        Some(s.interface.units_info().get_unit_health(id).ok()?.health)
    }
    fn set(s: &mut UnitModel, id: i32, health: &f32) {
        s.set_health_amounts(id, Some(*health), None, None, None, None);
    }
}
inventory::submit! { FieldEntry::of::<Health>() }

struct MaxHealth;
impl TypedField<UnitModel> for MaxHealth {
    type Value = f32;
    const DESCRIPTOR: ObjectFieldDescriptor = ObjectFieldDescriptor {
        name: "maxHealth",
        value_type: FieldValueType::Float,
        range: Some(FieldRange::at_least(1.0)),
        description: "Maximum unit health.",
    };
    fn get(s: &UnitModel, id: i32) -> Option<f32> {
        Some(s.interface.units_info().get_unit_health(id).ok()?.maxHealth)
    }
    fn set(s: &mut UnitModel, id: i32, max_health: &f32) {
        s.set_health_amounts(id, None, Some(*max_health), None, None, None);
    }
}
inventory::submit! { FieldEntry::of::<MaxHealth>() }

struct Paralyze;
impl TypedField<UnitModel> for Paralyze {
    type Value = f32;
    const DESCRIPTOR: ObjectFieldDescriptor = ObjectFieldDescriptor {
        name: "paralyze",
        value_type: FieldValueType::Float,
        range: Some(FieldRange::at_least(0.0)),
        description: "Current paralyze damage.",
    };
    fn get(s: &UnitModel, id: i32) -> Option<f32> {
        Some(
            s.interface
                .units_info()
                .get_unit_health(id)
                .ok()?
                .paralyzeDamage,
        )
    }
    fn set(s: &mut UnitModel, id: i32, paralyze: &f32) {
        s.set_health_amounts(id, None, None, Some(*paralyze), None, None);
    }
}
inventory::submit! { FieldEntry::of::<Paralyze>() }

struct Capture;
impl TypedField<UnitModel> for Capture {
    type Value = f32;
    const DESCRIPTOR: ObjectFieldDescriptor = ObjectFieldDescriptor {
        name: "capture",
        value_type: FieldValueType::Float,
        range: Some(FieldRange::between(0.0, 1.0)),
        description: "Current capture progress.",
    };
    fn get(s: &UnitModel, id: i32) -> Option<f32> {
        Some(
            s.interface
                .units_info()
                .get_unit_health(id)
                .ok()?
                .captureProgress,
        )
    }
    fn set(s: &mut UnitModel, id: i32, capture: &f32) {
        s.set_health_amounts(id, None, None, None, Some(*capture), None);
    }
}
inventory::submit! { FieldEntry::of::<Capture>() }

struct Build;
impl TypedField<UnitModel> for Build {
    type Value = f32;
    const DESCRIPTOR: ObjectFieldDescriptor = ObjectFieldDescriptor {
        name: "build",
        value_type: FieldValueType::Float,
        range: Some(FieldRange::between(0.0, 1.0)),
        description: "Current build progress.",
    };
    fn get(s: &UnitModel, id: i32) -> Option<f32> {
        Some(
            s.interface
                .units_info()
                .get_unit_health(id)
                .ok()?
                .buildProgress,
        )
    }
    fn set(s: &mut UnitModel, id: i32, build: &f32) {
        s.set_health_amounts(id, None, None, None, None, Some(*build));
    }
}
inventory::submit! { FieldEntry::of::<Build>() }

struct Tooltip;
impl TypedField<UnitModel> for Tooltip {
    type Value = String;
    const DESCRIPTOR: ObjectFieldDescriptor = ObjectFieldDescriptor {
        name: "tooltip",
        value_type: FieldValueType::String,
        range: None,
        description: "Unit tooltip text.",
    };
    fn get(s: &UnitModel, id: i32) -> Option<String> {
        s.interface.units_info().get_unit_tooltip(id).ok().flatten()
    }
    fn set(s: &mut UnitModel, id: i32, tooltip: &String) {
        let _ = s
            .interface
            .synced_ctrl()
            .unit()
            .set_unit_tooltip(id, tooltip);
    }
}
inventory::submit! { FieldEntry::of::<Tooltip>() }

struct Stockpile;
impl TypedField<UnitModel> for Stockpile {
    type Value = i32;
    const DESCRIPTOR: ObjectFieldDescriptor = ObjectFieldDescriptor {
        name: "stockpile",
        value_type: FieldValueType::Int,
        range: Some(FieldRange::at_least(0.0)),
        description: "Stockpiled weapon count.",
    };
    fn get(s: &UnitModel, id: i32) -> Option<i32> {
        let (stockpile, _) = s.interface.units_info().get_unit_stockpile(id).ok()?;
        Some(stockpile.stockpile as i32)
    }
    fn set(s: &mut UnitModel, id: i32, stockpile: &i32) {
        let _ = s
            .interface
            .synced_ctrl()
            .unit()
            .set_unit_stockpile(id, *stockpile, 0.0);
    }
}
inventory::submit! { FieldEntry::of::<Stockpile>() }

struct Experience;
impl TypedField<UnitModel> for Experience {
    type Value = f32;
    const DESCRIPTOR: ObjectFieldDescriptor = ObjectFieldDescriptor {
        name: "experience",
        value_type: FieldValueType::Float,
        range: Some(FieldRange::at_least(0.0)),
        description: "Unit experience.",
    };
    fn get(s: &UnitModel, id: i32) -> Option<f32> {
        s.interface.units_info().get_unit_experience(id).ok()
    }
    fn set(s: &mut UnitModel, id: i32, experience: &f32) {
        let _ = s
            .interface
            .synced_ctrl()
            .unit()
            .set_unit_experience(id, *experience);
    }
}
inventory::submit! { FieldEntry::of::<Experience>() }

struct Neutral;
impl TypedField<UnitModel> for Neutral {
    type Value = bool;
    const DESCRIPTOR: ObjectFieldDescriptor = ObjectFieldDescriptor {
        name: "neutral",
        value_type: FieldValueType::Bool,
        range: None,
        description: "Whether the unit is neutral.",
    };
    fn get(s: &UnitModel, id: i32) -> Option<bool> {
        s.interface.units_info().get_unit_neutral(id).ok()
    }
    fn set(s: &mut UnitModel, id: i32, neutral: &bool) {
        let _ = s
            .interface
            .synced_ctrl()
            .unit()
            .set_unit_neutral(id, *neutral);
    }
}
inventory::submit! { FieldEntry::of::<Neutral>() }

struct MoveCtrl;
impl TypedField<UnitModel> for MoveCtrl {
    type Value = bool;
    const DESCRIPTOR: ObjectFieldDescriptor = ObjectFieldDescriptor {
        name: "movectrl",
        value_type: FieldValueType::Bool,
        range: None,
        description: "Whether unit move-control is enabled.",
    };
    fn get(s: &UnitModel, id: i32) -> Option<bool> {
        s.interface.move_ctrl().is_move_ctrl_enabled(id).ok()
    }
    fn set(s: &mut UnitModel, id: i32, movectrl: &bool) {
        let _ = s.interface.move_ctrl().move_ctrl(id, *movectrl);
    }
}
inventory::submit! { FieldEntry::of::<MoveCtrl>() }

struct Gravity;
impl TypedField<UnitModel> for Gravity {
    type Value = f32;
    const DESCRIPTOR: ObjectFieldDescriptor = ObjectFieldDescriptor {
        name: "gravity",
        value_type: FieldValueType::Float,
        range: None,
        description: "Unit gravity override.",
    };
    fn get(_s: &UnitModel, _id: i32) -> Option<f32> {
        None
    }
    fn set(s: &mut UnitModel, id: i32, gravity: &f32) {
        let _ = s.interface.move_ctrl().set_move_ctrl_gravity(id, *gravity);
    }
}
inventory::submit! { FieldEntry::of::<Gravity>() }

struct HarvestStorageField;
impl TypedField<UnitModel> for HarvestStorageField {
    type Value = HarvestStorage;
    const DESCRIPTOR: ObjectFieldDescriptor = ObjectFieldDescriptor {
        name: "harvestStorage",
        value_type: FieldValueType::Object("HarvestStorage"),
        range: Some(FieldRange::at_least(0.0)),
        description: "Harvested resource storage.",
    };
    fn get(s: &UnitModel, id: i32) -> Option<HarvestStorage> {
        let h = s.interface.units_info().get_unit_harvest_storage(id).ok()?;
        Some(HarvestStorage {
            stored_metal: h.storedMetal,
            max_stored_metal: h.maxStoredMetal,
            stored_energy: h.storedEnergy,
            max_stored_energy: h.maxStoredEnergy,
        })
    }
    fn set(s: &mut UnitModel, id: i32, hs: &HarvestStorage) {
        let _ = s.interface.synced_ctrl().unit().set_unit_harvest_storage(
            id,
            hs.stored_metal,
            hs.max_stored_metal,
            hs.stored_energy,
            hs.max_stored_energy,
        );
    }
}
inventory::submit! { FieldEntry::of::<HarvestStorageField>() }

struct ResourcesField;
impl TypedField<UnitModel> for ResourcesField {
    type Value = UnitResources;
    const DESCRIPTOR: ObjectFieldDescriptor = ObjectFieldDescriptor {
        name: "resources",
        value_type: FieldValueType::Object("UnitResources"),
        range: Some(FieldRange::at_least(0.0)),
        description: "Unit resource production/use rates.",
    };
    fn get(s: &UnitModel, id: i32) -> Option<UnitResources> {
        let r = s.interface.units_info().get_unit_resources(id).ok()?;
        Some(UnitResources {
            metal_make: r.metalMake,
            metal_use: r.metalUse,
            energy_make: r.energyMake,
            energy_use: r.energyUse,
        })
    }
    fn set(s: &mut UnitModel, id: i32, r: &UnitResources) {
        let synced = s.interface.synced_ctrl();
        let unit = synced.unit();
        let _ = unit.set_unit_resourcing(id, "umm", r.metal_make);
        let _ = unit.set_unit_resourcing(id, "umu", r.metal_use);
        let _ = unit.set_unit_resourcing(id, "uem", r.energy_make);
        let _ = unit.set_unit_resourcing(id, "ueu", r.energy_use);
    }
}
inventory::submit! { FieldEntry::of::<ResourcesField>() }

struct ArmoredField;
impl TypedField<UnitModel> for ArmoredField {
    type Value = Armored;
    const DESCRIPTOR: ObjectFieldDescriptor = ObjectFieldDescriptor {
        name: "armored",
        value_type: FieldValueType::Object("Armored"),
        range: Some(FieldRange::at_least(0.0)),
        description: "Armored state and damage multiplier.",
    };
    fn get(s: &UnitModel, id: i32) -> Option<Armored> {
        let a = s.interface.units_info().get_unit_armored(id).ok()?;
        Some(Armored {
            armored: a.armored,
            armor_multiple: a.armorMultiple,
        })
    }
    fn set(s: &mut UnitModel, id: i32, a: &Armored) {
        let _ = s
            .interface
            .synced_ctrl()
            .unit()
            .set_unit_armored(id, a.armored, a.armor_multiple);
    }
}
inventory::submit! { FieldEntry::of::<ArmoredField>() }

struct Crashing;
impl TypedField<UnitModel> for Crashing {
    type Value = bool;
    const DESCRIPTOR: ObjectFieldDescriptor = ObjectFieldDescriptor {
        name: "crashing",
        value_type: FieldValueType::Bool,
        range: None,
        description: "Whether the unit is crashing.",
    };
    fn get(s: &UnitModel, id: i32) -> Option<bool> {
        let (is_aircraft, crashing) = s.interface.units_info().get_unit_crashing(id).ok()?;
        is_aircraft.then_some(crashing)
    }
    fn set(s: &mut UnitModel, id: i32, crashing: &bool) {
        let _ = s
            .interface
            .synced_ctrl()
            .unit()
            .set_unit_crashing(id, *crashing);
    }
}
inventory::submit! { FieldEntry::of::<Crashing>() }

struct Rules;
impl TypedField<UnitModel> for Rules {
    type Value = HashMap<String, RuleValue>;
    const DESCRIPTOR: ObjectFieldDescriptor = ObjectFieldDescriptor {
        name: "rules",
        value_type: FieldValueType::RulesMap,
        range: None,
        description: "Unit rules params keyed by param name.",
    };
    fn get(s: &UnitModel, id: i32) -> Option<HashMap<String, RuleValue>> {
        read_rules(&s.interface, id)
    }
    fn set(s: &mut UnitModel, id: i32, rules: &HashMap<String, RuleValue>) {
        write_rules(&s.interface, id, rules);
    }
}
inventory::submit! { FieldEntry::of::<Rules>() }

struct States;
impl TypedField<UnitModel> for States {
    type Value = UnitStates;
    const DESCRIPTOR: ObjectFieldDescriptor = ObjectFieldDescriptor {
        name: "states",
        value_type: FieldValueType::Object("UnitStates"),
        range: None,
        description: "Unit command/state toggles.",
    };
    fn get(s: &UnitModel, id: i32) -> Option<UnitStates> {
        read_states(&s.interface, id)
    }
    fn set(s: &mut UnitModel, id: i32, states: &UnitStates) {
        write_states(&s.interface, id, states);
    }
}
inventory::submit! { FieldEntry::of::<States>() }

struct Commands;
impl TypedField<UnitModel> for Commands {
    type Value = Vec<UnitCommand>;
    const DESCRIPTOR: ObjectFieldDescriptor = ObjectFieldDescriptor {
        name: "commands",
        value_type: FieldValueType::CommandList,
        range: None,
        description: "Queued unit commands.",
    };
    fn get(s: &UnitModel, id: i32) -> Option<Vec<UnitCommand>> {
        read_commands(&s.interface, &s.ids, id)
    }
    fn set(s: &mut UnitModel, id: i32, commands: &Vec<UnitCommand>) {
        write_commands(&s.interface, &s.ids, id, commands);
    }
}
inventory::submit! { FieldEntry::of::<Commands>() }

fn vec3_add(a: &Vec3, b: &Vec3) -> Vec3 {
    Vec3 {
        x: a.x + b.x,
        y: a.y + b.y,
        z: a.z + b.z,
    }
}
