use spring_native::{prelude::sys, RulesParamValue};

/// An object def reference. Placement sends the numeric `objectDefID`;
/// serialized objects carry the def's name. Resolve to an engine id at `add`.
#[derive(Debug, Clone, serde::Serialize, serde::Deserialize)]
#[serde(untagged)]
pub enum DefRef {
    Id(i32),
    Name(String),
}

impl Default for DefRef {
    fn default() -> Self {
        DefRef::Name(String::new())
    }
}

/// One rules-param value. The engine's `RulesParamValue` is a bool/float/string
/// tagged union; on the wire it's a bare scalar, so an untagged enum maps both ways.
#[derive(Debug, Clone, serde::Serialize, serde::Deserialize)]
#[serde(untagged)]
pub enum RuleValue {
    Bool(bool),
    Number(f32),
    String(String),
}

#[derive(Debug, Clone, Copy, Default, serde::Serialize, serde::Deserialize)]
pub struct Vec3 {
    pub x: f32,
    pub y: f32,
    pub z: f32,
}

/// `pos`-relative mid/aim offsets.
#[derive(Debug, Clone, Copy, serde::Serialize, serde::Deserialize)]
pub struct MidAimPos {
    pub mid: Vec3,
    pub aim: Vec3,
}

#[derive(Debug, Clone, Copy, serde::Serialize, serde::Deserialize)]
pub struct Blocking {
    #[serde(rename = "isBlocking")]
    pub is_blocking: bool,
    #[serde(rename = "isSolidObjectCollidable")]
    pub is_solid_object_collidable: bool,
    #[serde(rename = "isProjectileCollidable")]
    pub is_projectile_collidable: bool,
    #[serde(rename = "isRaySegmentCollidable")]
    pub is_ray_segment_collidable: bool,
    pub crushable: bool,
    #[serde(rename = "blockEnemyPushing")]
    pub block_enemy_pushing: bool,
    #[serde(rename = "blockHeightChanges")]
    pub block_height_changes: bool,
}

#[derive(Debug, Clone, Copy, serde::Serialize, serde::Deserialize)]
pub struct RadiusHeight {
    pub radius: f32,
    pub height: f32,
}

#[derive(Debug, Clone, Copy, serde::Serialize, serde::Deserialize)]
pub struct Collision {
    #[serde(rename = "scaleX")]
    pub scale_x: f32,
    #[serde(rename = "scaleY")]
    pub scale_y: f32,
    #[serde(rename = "scaleZ")]
    pub scale_z: f32,
    #[serde(rename = "offsetX")]
    pub offset_x: f32,
    #[serde(rename = "offsetY")]
    pub offset_y: f32,
    #[serde(rename = "offsetZ")]
    pub offset_z: f32,
    #[serde(rename = "vType")]
    pub v_type: i32,
    #[serde(rename = "testType")]
    pub test_type: i32,
    pub axis: i32,
}

/// Feature resources: stored amounts and reclaim state. The editor sends either
/// the full set or just `{metal, energy}`, so every field is optional; unknown
/// fields are rejected (and warned) instead of silently dropped.
#[serde_with::skip_serializing_none]
#[derive(Debug, Clone, Copy, Default, serde::Serialize, serde::Deserialize)]
#[serde(deny_unknown_fields)]
pub struct FeatureResources {
    pub metal: Option<f32>,
    pub energy: Option<f32>,
    #[serde(rename = "metalMax")]
    pub metal_max: Option<f32>,
    #[serde(rename = "energyMax")]
    pub energy_max: Option<f32>,
    #[serde(rename = "reclaimLeft")]
    pub reclaim_left: Option<f32>,
    #[serde(rename = "reclaimTime")]
    pub reclaim_time: Option<f32>,
}

#[serde_with::skip_serializing_none]
#[derive(Debug, Clone, Default, serde::Serialize, serde::Deserialize)]
pub struct UnitStates {
    #[serde(rename = "fireState")]
    pub fire_state: Option<i32>,
    #[serde(rename = "moveState")]
    pub move_state: Option<i32>,
    #[serde(rename = "autoRepairLevel")]
    pub auto_repair_level: Option<f32>,
    #[serde(rename = "repeat")]
    pub repeat: Option<bool>,
    pub cloak: Option<bool>,
    pub active: Option<bool>,
    pub trajectory: Option<bool>,
    #[serde(rename = "autoLand")]
    pub auto_land: Option<bool>,
    #[serde(rename = "loopbackAttack")]
    pub loopback_attack: Option<bool>,
}

#[serde_with::skip_serializing_none]
#[derive(Debug, Clone, serde::Serialize, serde::Deserialize)]
pub struct UnitCommand {
    pub id: Option<i32>,
    pub name: Option<String>,
    pub params: Option<Vec<f32>>,
    #[serde(rename = "buildUnitDef")]
    pub build_unit_def: Option<String>,
}

#[derive(Debug, Clone, Copy, serde::Serialize, serde::Deserialize)]
pub struct HarvestStorage {
    #[serde(rename = "storedMetal")]
    pub stored_metal: f32,
    #[serde(rename = "maxStoredMetal")]
    pub max_stored_metal: f32,
    #[serde(rename = "storedEnergy")]
    pub stored_energy: f32,
    #[serde(rename = "maxStoredEnergy")]
    pub max_stored_energy: f32,
}

#[derive(Debug, Clone, Copy, serde::Serialize, serde::Deserialize)]
pub struct UnitFuel {
    pub fuel: f32,
    #[serde(rename = "maxFuel")]
    pub max_fuel: f32,
}

#[derive(Debug, Clone, Copy, serde::Serialize, serde::Deserialize)]
#[serde(deny_unknown_fields)]
pub struct UnitResources {
    #[serde(rename = "metalMake")]
    pub metal_make: f32,
    #[serde(rename = "metalUse")]
    pub metal_use: f32,
    #[serde(rename = "energyMake")]
    pub energy_make: f32,
    #[serde(rename = "energyUse")]
    pub energy_use: f32,
}

#[derive(Debug, Clone, Copy, serde::Serialize, serde::Deserialize)]
pub struct Armored {
    pub armored: bool,
    #[serde(rename = "armorMultiple")]
    pub armor_multiple: f32,
}

impl From<Vec3> for sys::Float3 {
    fn from(v: Vec3) -> Self {
        sys::Float3 {
            x: v.x,
            y: v.y,
            z: v.z,
        }
    }
}

impl From<sys::Float3> for Vec3 {
    fn from(v: sys::Float3) -> Self {
        Vec3 {
            x: v.x,
            y: v.y,
            z: v.z,
        }
    }
}

impl From<RulesParamValue> for RuleValue {
    fn from(value: RulesParamValue) -> Self {
        match value {
            RulesParamValue::Bool(value) => RuleValue::Bool(value),
            RulesParamValue::Float(value) => RuleValue::Number(value),
            RulesParamValue::String(value) => RuleValue::String(value),
        }
    }
}

impl From<&RuleValue> for RulesParamValue {
    fn from(value: &RuleValue) -> Self {
        match value {
            RuleValue::Bool(value) => RulesParamValue::Bool(*value),
            RuleValue::Number(value) => RulesParamValue::Float(*value),
            RuleValue::String(value) => RulesParamValue::String(value.clone()),
        }
    }
}
