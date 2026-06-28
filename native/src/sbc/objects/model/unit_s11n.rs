use spring_native::prelude::{constants, sys, NativeInterfaceRef};

use super::model_id_map::ModelIdMap;
use super::object_data::{
    Armored, Blocking, Collision, HarvestStorage, MidAimPos, ObjectData, RadiusHeight, Resources,
    RuleValue, UnitStates, Vec3,
};
use crate::sbc::lua_bridge;
use std::collections::HashMap;

/// Synced-side unit serialization + lifecycle.
pub struct UnitS11n {
    interface: NativeInterfaceRef,
    ids: ModelIdMap,
}

impl UnitS11n {
    pub fn new(interface: NativeInterfaceRef) -> Self {
        UnitS11n {
            interface,
            ids: ModelIdMap::default(),
        }
    }

    pub fn spring_id(&self, model_id: i32) -> Option<i32> {
        self.ids.spring_id(model_id)
    }

    pub fn latest_model_id(&self) -> i32 {
        self.ids.latest_model_id()
    }

    /// Every live unit's fields, ordered by modelID; each carries its `__modelID`
    /// so `load_all` re-creates it with the same stable id.
    pub fn serialize_all(&self) -> Vec<ObjectData> {
        let mut entries: Vec<(i32, i32)> = self.ids.entries().collect();
        entries.sort_by_key(|&(_, m)| m);
        entries
            .into_iter()
            .filter_map(|(spring_id, _)| self.get(spring_id))
            .collect()
    }

    pub fn load_all(&mut self, objects: &[ObjectData]) {
        for object in objects {
            self.add(object);
        }
    }

    pub fn clear_all(&mut self) {
        let spring_ids: Vec<i32> = self.ids.entries().map(|(s, _)| s).collect();
        for spring_id in spring_ids {
            self.remove(spring_id);
        }
    }

    /// Create a unit and apply its fields. Returns the allocated modelID, or
    /// `None` if the engine refused to create the unit.
    pub fn add(&mut self, object: &ObjectData) -> Option<i32> {
        let def_id = self
            .interface
            .unit_defs()
            .get_unit_def_idby_name(&object.def_name)
            .ok()?;
        if def_id < 0 {
            return None;
        }
        // The engine resolves the def by `id` when id >= 0, so a null name is fine.
        let unit_def = sys::DefRef {
            name: std::ptr::null(),
            id: def_id,
        };
        let team = object.team.unwrap_or(0);
        let spring_id = self
            .interface
            .synced_ctrl()
            .unit()
            .create_unit(unit_def, object.pos.into(), 0, team, false, false, -1, -1)
            .ok()?;
        if spring_id < 0 {
            return None;
        }

        self.apply_fields(spring_id, object, true);

        let model_id = self.ids.register(spring_id, object.model_id);
        notify_added(&self.interface, spring_id, model_id);
        Some(model_id)
    }

    /// Apply a partial field set: only `Some` fields are written; `pos` is
    /// written only if `apply_pos` (it has no `Option` to carry its absence).
    pub fn set_fields(&self, spring_id: i32, object: &ObjectData, apply_pos: bool) {
        self.apply_fields(spring_id, object, apply_pos);
    }

    pub fn get(&self, spring_id: i32) -> Option<ObjectData> {
        let info = self.interface.units_info();
        let def_id = info.get_unit_def_id(spring_id).ok()?;
        let def_name = self
            .interface
            .unit_defs()
            .get_unit_def_name(def_id)
            .ok()??;
        let pos: Vec3 = info.get_unit_position(spring_id, false, false).ok()?.into();

        let rot = info.get_unit_rotation(spring_id).ok().map(|r| Vec3 {
            x: r.pitch,
            y: r.yaw,
            z: r.roll,
        });
        let vel = info.get_unit_velocity(spring_id).ok().map(Into::into);
        let dir = info.get_unit_direction(spring_id).ok().map(Into::into);
        let mass = info.get_unit_mass(spring_id).ok();
        // The engine returns absolute mid/aim points; store them relative to pos.
        let mid_aim_pos = match (
            info.get_unit_position(spring_id, true, false),
            info.get_unit_position(spring_id, false, true),
        ) {
            (Ok(mid), Ok(aim)) => Some(MidAimPos {
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
            }),
            _ => None,
        };
        let blocking = info.get_unit_blocking(spring_id).ok().map(|b| Blocking {
            is_blocking: b.isBlocking,
            is_solid_object_collidable: b.isSolidObjectCollidable,
            is_projectile_collidable: b.isProjectileCollidable,
            is_ray_segment_collidable: b.isRaySegmentCollidable,
            crushable: b.crushable,
            block_enemy_pushing: b.blockEnemyPushing,
            block_height_changes: b.blockHeightChanges,
        });
        let radius_height = match (
            info.get_unit_radius(spring_id),
            info.get_unit_height(spring_id),
        ) {
            (Ok(radius), Ok(height)) => Some(RadiusHeight { radius, height }),
            _ => None,
        };
        let collision = info
            .get_unit_collision_volume_data(spring_id)
            .ok()
            .map(|c| Collision {
                scale_x: c.scaleX,
                scale_y: c.scaleY,
                scale_z: c.scaleZ,
                offset_x: c.offsetX,
                offset_y: c.offsetY,
                offset_z: c.offsetZ,
                v_type: c.volumeType,
                test_type: c.testType,
                axis: c.primaryAxis,
            });
        let team = info.get_unit_team(spring_id).ok();
        let unit_health = info.get_unit_health(spring_id).ok();
        let health = unit_health.as_ref().map(|h| h.health);
        let max_health = unit_health.as_ref().map(|h| h.maxHealth);
        let paralyze = unit_health.as_ref().map(|h| h.paralyzeDamage);
        let capture = unit_health.as_ref().map(|h| h.captureProgress);
        let build = unit_health.as_ref().map(|h| h.buildProgress);
        let tooltip = info.get_unit_tooltip(spring_id).ok().flatten();
        let stockpile = info
            .get_unit_stockpile(spring_id)
            .ok()
            .map(|(s, _)| s.stockpile as i32);
        let experience = info.get_unit_experience(spring_id).ok();
        let neutral = info.get_unit_neutral(spring_id).ok();
        let harvest_storage =
            info.get_unit_harvest_storage(spring_id)
                .ok()
                .map(|h| HarvestStorage {
                    stored_metal: h.storedMetal,
                    max_stored_metal: h.maxStoredMetal,
                    stored_energy: h.storedEnergy,
                    max_stored_energy: h.maxStoredEnergy,
                });
        let resources = info.get_unit_resources(spring_id).ok().map(|r| Resources {
            metal_make: r.metalMake,
            metal_use: r.metalUse,
            energy_make: r.energyMake,
            energy_use: r.energyUse,
        });
        let armored = info.get_unit_armored(spring_id).ok().map(|a| Armored {
            armored: a.armored,
            armor_multiple: a.armorMultiple,
        });
        let max_range = self
            .interface
            .units_weapons()
            .get_unit_max_range(spring_id)
            .ok();
        // Only aircraft have a crashing state; leave it unset for everything else.
        let crashing = info
            .get_unit_crashing(spring_id)
            .ok()
            .and_then(|(is_aircraft, crashing)| is_aircraft.then_some(crashing));
        let rules = read_rules(&self.interface, spring_id);
        let states = read_states(&self.interface, spring_id);

        Some(ObjectData {
            def_name,
            pos,
            rot,
            vel,
            dir,
            mass,
            mid_aim_pos,
            max_range,
            blocking,
            radius_height,
            collision,
            team,
            health,
            max_health,
            paralyze,
            capture,
            build,
            tooltip,
            stockpile,
            experience,
            neutral,
            harvest_storage,
            resources,
            armored,
            crashing,
            rules,
            states,
            model_id: self.ids.model_id(spring_id),
        })
    }

    pub fn remove(&mut self, spring_id: i32) {
        let _ = self
            .interface
            .synced_ctrl()
            .unit()
            .destroy_unit(spring_id, false, true, -1, false);
        self.ids.unregister(spring_id);
        notify_removed(&self.interface, spring_id);
    }

    fn apply_fields(&self, spring_id: i32, object: &ObjectData, apply_pos: bool) {
        let synced = self.interface.synced_ctrl();
        let unit = synced.unit();
        // Setting position resets a building's facing, so rot is applied first
        // and re-applied at the end.
        if let Some(rot) = object.rot {
            let _ = unit.set_unit_rotation(spring_id, rot.into());
        }
        if apply_pos {
            let _ = unit.set_unit_position(spring_id, object.pos.into());
        }
        if let Some(vel) = object.vel {
            let _ = unit.set_unit_velocity(spring_id, vel.into());
        }
        if let Some(dir) = object.dir {
            // The engine needs a front+right pair; derive an orthogonal right.
            let right = sys::Float3 {
                x: -dir.z,
                y: 0.0,
                z: dir.x,
            };
            let _ = unit.set_unit_direction(spring_id, dir.into(), right);
        }
        if let Some(mass) = object.mass {
            let _ = unit.set_unit_mass(spring_id, mass);
        }
        if let Some(mid_aim) = object.mid_aim_pos {
            let _ = unit.set_unit_mid_and_aim_pos(
                spring_id,
                mid_aim.mid.into(),
                mid_aim.aim.into(),
                true,
            );
        }
        if let Some(max_range) = object.max_range {
            let _ = unit.set_unit_max_range(spring_id, max_range);
        }
        if let Some(b) = object.blocking {
            let _ = unit.set_unit_blocking(
                spring_id,
                b.is_blocking,
                b.is_solid_object_collidable,
                b.is_projectile_collidable,
                b.is_ray_segment_collidable,
                b.crushable,
                b.block_enemy_pushing,
                b.block_height_changes,
            );
        }
        if let Some(rh) = object.radius_height {
            let _ = unit.set_unit_radius_and_height(spring_id, rh.radius, rh.height);
        }
        if let Some(c) = object.collision {
            let _ = unit.set_unit_collision_volume_data(
                spring_id,
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
                1,
                c.axis,
            );
        }
        // The health family shares one engine call, so set them together when
        // any is present.
        if object.health.is_some()
            || object.max_health.is_some()
            || object.paralyze.is_some()
            || object.capture.is_some()
            || object.build.is_some()
        {
            if let Some(max_health) = object.max_health {
                let _ = unit.set_unit_max_health(spring_id, max_health);
            }
            let use_amounts =
                object.paralyze.is_some() || object.capture.is_some() || object.build.is_some();
            let _ = unit.set_unit_health(
                spring_id,
                sys::UnitHealthValue {
                    health: object.health.unwrap_or(0.0),
                    capture: object.capture.unwrap_or(0.0),
                    paralyze: object.paralyze.unwrap_or(0.0),
                    build: object.build.unwrap_or(0.0),
                    useAmounts: use_amounts,
                },
            );
        }
        if let Some(tooltip) = &object.tooltip {
            let _ = unit.set_unit_tooltip(spring_id, tooltip);
        }
        if let Some(stockpile) = object.stockpile {
            let _ = unit.set_unit_stockpile(spring_id, stockpile, 0.0);
        }
        if let Some(experience) = object.experience {
            let _ = unit.set_unit_experience(spring_id, experience);
        }
        if let Some(neutral) = object.neutral {
            let _ = unit.set_unit_neutral(spring_id, neutral);
        }
        if let Some(hs) = object.harvest_storage {
            let _ = unit.set_unit_harvest_storage(
                spring_id,
                hs.stored_metal,
                hs.max_stored_metal,
                hs.stored_energy,
                hs.max_stored_energy,
            );
        }
        if let Some(r) = object.resources {
            let _ = unit.set_unit_resourcing(spring_id, "umm", r.metal_make);
            let _ = unit.set_unit_resourcing(spring_id, "cum", r.metal_use);
            let _ = unit.set_unit_resourcing(spring_id, "ume", r.energy_make);
            let _ = unit.set_unit_resourcing(spring_id, "cue", r.energy_use);
        }
        if let Some(a) = object.armored {
            let _ = unit.set_unit_armored(spring_id, a.armored, a.armor_multiple);
        }
        if let Some(crashing) = object.crashing {
            let _ = unit.set_unit_crashing(spring_id, crashing);
        }
        if let Some(rules) = &object.rules {
            write_rules(&self.interface, spring_id, rules);
        }
        if let Some(states) = &object.states {
            write_states(&self.interface, spring_id, states);
        }
        if let Some(team) = object.team {
            if self.interface.units_info().get_unit_team(spring_id).ok() != Some(team) {
                let _ = unit.transfer_unit(spring_id, team, false, false);
            }
        }
        if let Some(rot) = object.rot {
            let _ = unit.set_unit_rotation(spring_id, rot.into());
        }
    }
}

/// Read a unit's rules params into a name→value map. `None` if it has none, so
/// the field is omitted from the serialized object.
fn read_rules(
    interface: &NativeInterfaceRef,
    spring_id: i32,
) -> Option<HashMap<String, RuleValue>> {
    let rules = interface.rules_params();
    let names = rules.get_unit_rules_params(spring_id).ok()?;
    if names.is_empty() {
        return None;
    }
    let mut out = HashMap::with_capacity(names.len());
    for name in names {
        if let Ok((value, _los, exists)) = rules.get_unit_rules_param(spring_id, &name) {
            if exists {
                // SAFETY: the engine tags `value.type_` for values it returns.
                out.insert(name, unsafe { RuleValue::from_sys(&value) });
            }
        }
    }
    Some(out)
}

fn write_rules(interface: &NativeInterfaceRef, spring_id: i32, rules: &HashMap<String, RuleValue>) {
    let api = interface.rules_params();
    for (name, value) in rules {
        // A `String` value's sys pointer must stay alive across the call.
        let cstr;
        let sys_value = match value {
            RuleValue::Bool(b) => sys::RulesParamValue {
                type_: sys::RulesParamType_RULESPARAM_TYPE_BOOL,
                __bindgen_anon_1: sys::RulesParamValue__bindgen_ty_1 { boolValue: *b },
            },
            RuleValue::Number(n) => sys::RulesParamValue {
                type_: sys::RulesParamType_RULESPARAM_TYPE_FLOAT,
                __bindgen_anon_1: sys::RulesParamValue__bindgen_ty_1 { floatValue: *n },
            },
            RuleValue::String(s) => {
                cstr = std::ffi::CString::new(s.as_str()).unwrap_or_default();
                sys::RulesParamValue {
                    type_: sys::RulesParamType_RULESPARAM_TYPE_STRING,
                    __bindgen_anon_1: sys::RulesParamValue__bindgen_ty_1 {
                        stringValue: cstr.as_ptr(),
                    },
                }
            }
        };
        let _ = api.set_unit_rules_param(spring_id, name, sys_value, RULES_PARAM_LOS_PRIVATE);
    }
}

/// LOS access for a rules-param set: private (readable by the owning ally).
const RULES_PARAM_LOS_PRIVATE: i32 = 1;

fn read_states(interface: &NativeInterfaceRef, spring_id: i32) -> Option<UnitStates> {
    let s = interface.units_info().get_unit_states(spring_id).ok()?;
    Some(UnitStates {
        fire_state: Some(s.fireState),
        move_state: Some(s.moveState),
        repeat: Some(s.repeat),
        cloak: Some(s.cloak),
        active: Some(s.active),
        trajectory: Some(s.trajectory),
    })
}

/// Apply present states as engine orders, one per state. Booleans map to a
/// single `1.0`/`0.0` param.
fn write_states(interface: &NativeInterfaceRef, spring_id: i32, states: &UnitStates) {
    let synced = interface.synced_ctrl();
    let unit = synced.unit();
    let order = |cmd: i32, value: f32| {
        let _ = unit.give_order_to_unit(spring_id, cmd, &[value], 0, -1);
    };
    let flag = |b: bool| if b { 1.0 } else { 0.0 };

    if let Some(v) = states.fire_state {
        order(constants::CMD_FIRE_STATE, v as f32);
    }
    if let Some(v) = states.move_state {
        order(constants::CMD_MOVE_STATE, v as f32);
    }
    if let Some(v) = states.active {
        order(constants::CMD_ONOFF, flag(v));
    }
    if let Some(v) = states.repeat {
        order(constants::CMD_REPEAT, flag(v));
    }
    if let Some(v) = states.cloak {
        order(constants::CMD_CLOAK, flag(v));
    }
    if let Some(v) = states.trajectory {
        order(constants::CMD_TRAJECTORY, flag(v));
    }
}

/// Tell the widget's object mirror about a new unit (it resolves `object` as the
/// modelID).
fn notify_added(interface: &NativeInterfaceRef, spring_id: i32, model_id: i32) {
    lua_bridge::send(
        interface,
        serde_json::json!({
            "tag": "command",
            "data": {
                "className": "WidgetAddObjectCommand",
                "objType": "unit",
                "objectID": spring_id,
                "object": model_id,
            }
        }),
    );
}

fn notify_removed(interface: &NativeInterfaceRef, spring_id: i32) {
    lua_bridge::send(
        interface,
        serde_json::json!({
            "tag": "command",
            "data": {
                "className": "WidgetRemoveObjectCommand",
                "objType": "unit",
                "objectID": spring_id,
            }
        }),
    );
}
