use spring_native::prelude::{sys, NativeInterfaceRef};

use super::model_id_map::ModelIdMap;
use super::object_data::{Blocking, Collision, ObjectData, RadiusHeight, RuleValue, Vec3};
use crate::sbc::lua_bridge;
use std::collections::HashMap;

/// Synced-side feature serialization + lifecycle. `team` is read-only on
/// features; feature `resources` has a different shape than [`Resources`] and is
/// deferred.
///
/// [`Resources`]: super::object_data::Resources
pub struct FeatureS11n {
    interface: NativeInterfaceRef,
    ids: ModelIdMap,
}

impl FeatureS11n {
    pub fn new(interface: NativeInterfaceRef) -> Self {
        FeatureS11n {
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

    /// Every live feature's fields, ordered by modelID; each carries its
    /// `__modelID` for `load_all`.
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

    pub fn add(&mut self, object: &ObjectData) -> Option<i32> {
        let def_id = self
            .interface
            .feature_defs()
            .get_feature_def_idby_name(&object.def_name)
            .ok()?;
        if def_id < 0 {
            return None;
        }
        let feature_def = sys::DefRef {
            name: std::ptr::null(),
            id: def_id,
        };
        let team = object.team.unwrap_or(0);
        let spring_id = self
            .interface
            .synced_ctrl()
            .feature()
            .create_feature(feature_def, object.pos.into(), 0, team, -1)
            .ok()?;
        if spring_id < 0 {
            return None;
        }

        self.apply_fields(spring_id, object, true);

        // The editor places features at the raycast-hit Y, not GetGroundHeight, so
        // a feature can land off the synced ground. Left alone it falls and bounces
        // forever, re-deriving its orientation each frame and spinning. Freeze its
        // physics (MoveCtrl) when off-ground, as the Lua editor does; on-ground
        // features settle on their own.
        let ground = self
            .interface
            .terrain()
            .get_ground_height(object.pos.x, object.pos.z)
            .unwrap_or(object.pos.y);
        let off_ground = (ground - object.pos.y).abs() >= 0.1;
        log::info!(
            "feature add spring_id={spring_id} pos_y={} ground={ground} off_ground={off_ground}",
            object.pos.y
        );
        if off_ground {
            let zero = sys::Float3 {
                x: 0.0,
                y: 0.0,
                z: 0.0,
            };
            let _ = self.interface.synced_ctrl().feature().set_feature_move_ctrl(
                spring_id, true, zero, zero, zero,
            );
        }

        let model_id = self.ids.register(spring_id, object.model_id);
        notify_added(&self.interface, spring_id, model_id);
        Some(model_id)
    }

    /// Apply a partial field set: only `Some` fields are written; `pos` is
    /// written only if `apply_pos`.
    pub fn set_fields(&self, spring_id: i32, object: &ObjectData, apply_pos: bool) {
        self.apply_fields(spring_id, object, apply_pos);
    }

    pub fn get(&self, spring_id: i32) -> Option<ObjectData> {
        let info = self.interface.features();
        let def_id = info.get_feature_def_id(spring_id).ok()?;
        let def_name = self
            .interface
            .feature_defs()
            .get_feature_def_name(def_id)
            .ok()??;
        let pos: Vec3 = info.get_feature_position(spring_id).ok()?.into();

        let rot = info.get_feature_rotation(spring_id).ok().map(|r| Vec3 {
            x: r.pitch,
            y: r.yaw,
            z: r.roll,
        });
        let vel = info.get_feature_velocity(spring_id).ok().map(Into::into);
        let dir = info.get_feature_direction(spring_id).ok().map(Into::into);
        let mass = info.get_feature_mass(spring_id).ok();
        let blocking = info.get_feature_blocking(spring_id).ok().map(|b| Blocking {
            is_blocking: b.isBlocking,
            is_solid_object_collidable: b.isSolidObjectCollidable,
            is_projectile_collidable: b.isProjectileCollidable,
            is_ray_segment_collidable: b.isRaySegmentCollidable,
            crushable: b.crushable,
            block_enemy_pushing: b.blockEnemyPushing,
            block_height_changes: b.blockHeightChanges,
        });
        let radius_height = match (
            info.get_feature_radius(spring_id),
            info.get_feature_height(spring_id),
        ) {
            (Ok(radius), Ok(height)) => Some(RadiusHeight { radius, height }),
            _ => None,
        };
        let collision = info
            .get_feature_collision_volume_data(spring_id)
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
        let team = info.get_feature_team(spring_id).ok();
        let health = info.get_feature_health(spring_id).ok().map(|h| h.health);
        let rules = read_rules(&self.interface, spring_id);

        Some(ObjectData {
            def_name,
            pos,
            rot,
            vel,
            dir,
            mass,
            blocking,
            radius_height,
            collision,
            team,
            health,
            rules,
            model_id: self.ids.model_id(spring_id),
            ..Default::default()
        })
    }

    pub fn remove(&mut self, spring_id: i32) {
        let _ = self
            .interface
            .synced_ctrl()
            .feature()
            .destroy_feature(spring_id);
        self.ids.unregister(spring_id);
        notify_removed(&self.interface, spring_id);
    }

    fn apply_fields(&self, spring_id: i32, object: &ObjectData, apply_pos: bool) {
        let synced = self.interface.synced_ctrl();
        let feature = synced.feature();
        if let Some(rot) = object.rot {
            let _ = feature.set_feature_rotation(spring_id, rot.into());
        }
        if apply_pos {
            let _ = feature.set_feature_position(spring_id, object.pos.into(), false);
        }
        if let Some(vel) = object.vel {
            let _ = feature.set_feature_velocity(spring_id, vel.into());
        }
        if let Some(dir) = object.dir {
            // The engine needs a front+right pair; derive an orthogonal right.
            let right = sys::Float3 {
                x: -dir.z,
                y: 0.0,
                z: dir.x,
            };
            let _ = feature.set_feature_direction(spring_id, dir.into(), right);
        }
        if let Some(mass) = object.mass {
            let _ = feature.set_feature_mass(spring_id, mass);
        }
        if let Some(mid_aim) = object.mid_aim_pos {
            let _ = feature.set_feature_mid_and_aim_pos(
                spring_id,
                mid_aim.mid.into(),
                mid_aim.aim.into(),
                true,
            );
        }
        if let Some(b) = object.blocking {
            let _ = feature.set_feature_blocking(
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
            let _ = feature.set_feature_radius_and_height(spring_id, rh.radius, rh.height);
        }
        if let Some(c) = object.collision {
            let _ = feature.set_feature_collision_volume_data(
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
        if let Some(health) = object.health {
            let _ = feature.set_feature_health(spring_id, health, false);
        }
        if let Some(rules) = &object.rules {
            write_rules(&self.interface, spring_id, rules);
        }
        if let Some(rot) = object.rot {
            let _ = feature.set_feature_rotation(spring_id, rot.into());
        }
    }
}

/// Read a feature's rules params into a name→value map. `None` if it has none,
/// so the field is omitted from the serialized object.
fn read_rules(
    interface: &NativeInterfaceRef,
    spring_id: i32,
) -> Option<HashMap<String, RuleValue>> {
    let rules = interface.rules_params();
    let names = rules.get_feature_rules_params(spring_id).ok()?;
    if names.is_empty() {
        return None;
    }
    let mut out = HashMap::with_capacity(names.len());
    for name in names {
        if let Ok((value, _los, exists)) = rules.get_feature_rules_param(spring_id, &name) {
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
        let _ = api.set_feature_rules_param(spring_id, name, sys_value, RULES_PARAM_LOS_PRIVATE);
    }
}

/// LOS access for a rules-param set: private (readable by the owning ally).
const RULES_PARAM_LOS_PRIVATE: i32 = 1;

fn notify_added(interface: &NativeInterfaceRef, spring_id: i32, model_id: i32) {
    lua_bridge::send(
        interface,
        serde_json::json!({
            "tag": "command",
            "data": {
                "className": "WidgetAddObjectCommand",
                "objType": "feature",
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
                "objType": "feature",
                "objectID": spring_id,
            }
        }),
    );
}
