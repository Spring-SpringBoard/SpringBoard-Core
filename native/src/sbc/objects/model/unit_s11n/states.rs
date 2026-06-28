use spring_native::prelude::{constants, NativeInterfaceRef};

use crate::sbc::objects::model::object_data::UnitStates;

pub(super) fn read_states(interface: &NativeInterfaceRef, spring_id: i32) -> Option<UnitStates> {
    let s = interface.units_info().get_unit_states(spring_id).ok()?;
    Some(UnitStates {
        fire_state: Some(s.fireState),
        move_state: Some(s.moveState),
        auto_repair_level: Some(s.autoRepairLevel),
        repeat: Some(s.repeat),
        cloak: Some(s.cloak),
        active: Some(s.active),
        trajectory: Some(s.trajectory),
        auto_land: Some(s.autoLand),
        loopback_attack: Some(s.loopbackAttack),
    })
}

/// Apply present states as engine orders, one per state. Booleans map to a
/// single `1.0`/`0.0` param.
pub(super) fn write_states(interface: &NativeInterfaceRef, spring_id: i32, states: &UnitStates) {
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
    // Lua intentionally does not set autoRepairLevel here; the old comment says
    // it clears commands. Keep that behavior.
    if let Some(v) = states.loopback_attack {
        order(constants::CMD_LOOPBACKATTACK, flag(v));
    }
}
