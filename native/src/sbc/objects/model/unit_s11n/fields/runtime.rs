//! Unit fields whose values describe runtime ownership, health, and state.

use std::collections::HashMap;

use crate::sbc::objects::model::field::TypedField;
use crate::sbc::objects::model::field_descriptor::{
    FieldRange, FieldValueType, ObjectFieldDescriptor,
};
use crate::sbc::objects::model::object_data::{
    Armored, HarvestStorage, RuleValue, UnitCommand, UnitResources, UnitStates,
};

use super::super::commands::{read_commands, write_commands};
use super::super::model::UnitModel;
use super::super::rules::{read_rules, write_rules};
use super::super::states::{read_states, write_states};
use crate::sbc::objects::model::field::FieldEntry;

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

macro_rules! health_field {
    ($name:ident, $field:literal, $range:expr, $description:literal, $member:ident, $slot:expr) => {
        struct $name;
        impl TypedField<UnitModel> for $name {
            type Value = f32;
            const DESCRIPTOR: ObjectFieldDescriptor = ObjectFieldDescriptor {
                name: $field,
                value_type: FieldValueType::Float,
                range: Some($range),
                description: $description,
            };
            fn get(s: &UnitModel, id: i32) -> Option<f32> {
                Some(s.interface.units_info().get_unit_health(id).ok()?.$member)
            }
            fn set(s: &mut UnitModel, id: i32, value: &f32) {
                let (health, max_health, paralyze, capture, build) = ($slot)(*value);
                s.set_health_amounts(id, health, max_health, paralyze, capture, build);
            }
        }
        inventory::submit! { FieldEntry::of::<$name>() }
    };
}

health_field!(
    Health,
    "health",
    FieldRange::at_least(0.0),
    "Current unit health.",
    health,
    |value| (Some(value), None, None, None, None)
);
health_field!(
    MaxHealth,
    "maxHealth",
    FieldRange::at_least(1.0),
    "Maximum unit health.",
    maxHealth,
    |value| (None, Some(value), None, None, None)
);
health_field!(
    Paralyze,
    "paralyze",
    FieldRange::at_least(0.0),
    "Current paralyze damage.",
    paralyzeDamage,
    |value| (None, None, Some(value), None, None)
);
health_field!(
    Capture,
    "capture",
    FieldRange::between(0.0, 1.0),
    "Current capture progress.",
    captureProgress,
    |value| (None, None, None, Some(value), None)
);
health_field!(
    Build,
    "build",
    FieldRange::between(0.0, 1.0),
    "Current build progress.",
    buildProgress,
    |value| (None, None, None, None, Some(value))
);

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
        Some(
            s.interface
                .units_info()
                .get_unit_stockpile(id)
                .ok()?
                .0
                .stockpile as i32,
        )
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
