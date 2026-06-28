use spring_native::prelude::{constants, NativeInterfaceRef};
use spring_native::{CommandDescription, CommandType};

use crate::sbc::objects::model::model_id_map::ModelIdMap;

use crate::sbc::objects::model::object_data::UnitCommand;

pub(super) fn read_commands(
    interface: &NativeInterfaceRef,
    ids: &ModelIdMap,
    spring_id: i32,
) -> Option<Vec<UnitCommand>> {
    let commands = interface
        .units_commands()
        .get_unit_commands(spring_id, u32::MAX)
        .ok()?;
    if commands.is_empty() {
        return None;
    }
    let descriptions = command_descriptions(interface, spring_id);

    let mut out = Vec::with_capacity(commands.len());
    for command in commands {
        let params = interface
            .units_commands()
            .get_command_params(&command)
            .ok()
            .filter(|params| !params.is_empty());

        if command.cmdID < 0 {
            let build_unit_def = interface
                .unit_defs()
                .get_unit_def_name(command.cmdID.abs())
                .ok()
                .flatten();
            out.push(UnitCommand {
                id: None,
                name: Some("BUILD_COMMAND".to_string()),
                params,
                build_unit_def,
            });
            continue;
        }

        let description = descriptions.iter().find(|desc| desc.id == command.cmdID);
        let name = description.and_then(command_name);
        let mut params = params;
        if description.is_some_and(command_targets_unit) {
            if let Some(values) = params.as_mut().filter(|values| values.len() == 1) {
                if let Some(model_id) = ids.model_id(values[0] as i32) {
                    values[0] = model_id as f32;
                }
            }
        }

        out.push(UnitCommand {
            id: name.is_none().then_some(command.cmdID),
            name,
            params,
            build_unit_def: None,
        });
    }

    Some(out)
}

pub(super) fn write_commands(
    interface: &NativeInterfaceRef,
    ids: &ModelIdMap,
    spring_id: i32,
    commands: &[UnitCommand],
) {
    let synced_ctrl = interface.synced_ctrl();
    let unit = synced_ctrl.unit();
    let descriptions = command_descriptions(interface, spring_id);
    for command in commands {
        let mut params = command.params.clone().unwrap_or_default();
        let cmd_id = if command.name.as_deref() == Some("BUILD_COMMAND") {
            let Some(def_name) = command.build_unit_def.as_deref() else {
                continue;
            };
            match interface.unit_defs().get_unit_def_idby_name(def_name) {
                Ok(id) if id >= 0 => -id,
                _ => continue,
            }
        } else {
            let id = command
                .name
                .as_deref()
                .and_then(|name| command_id(&descriptions, name))
                .or(command.id);
            let Some(id) = id else {
                continue;
            };
            if descriptions
                .iter()
                .find(|desc| desc.id == id)
                .is_some_and(command_targets_unit)
                && params.len() == 1
            {
                let value = &mut params[0];
                if let Some(spring_target) = ids.spring_id(*value as i32) {
                    *value = spring_target as f32;
                }
            }
            id
        };

        let _ = unit.give_order_to_unit(spring_id, cmd_id, &params, constants::CMD_OPT_SHIFT, -1);
    }
}

fn command_descriptions(interface: &NativeInterfaceRef, spring_id: i32) -> Vec<CommandDescription> {
    interface
        .units_commands()
        .get_unit_command_descriptions(spring_id)
        .unwrap_or_default()
}

fn command_name(desc: &CommandDescription) -> Option<String> {
    if !desc.action.is_empty() {
        return Some(desc.action.to_ascii_uppercase());
    }
    (!desc.name.is_empty()).then(|| desc.name.to_ascii_uppercase())
}

fn command_id(descriptions: &[CommandDescription], name: &str) -> Option<i32> {
    descriptions
        .iter()
        .find_map(|desc| matches_command_name(desc, name).then_some(desc.id))
}

fn matches_command_name(desc: &CommandDescription, name: &str) -> bool {
    desc.action.eq_ignore_ascii_case(name) || desc.name.eq_ignore_ascii_case(name)
}

fn command_targets_unit(desc: &CommandDescription) -> bool {
    matches!(
        desc.command_type,
        CommandType::IconUnit
            | CommandType::IconUnitOrMap
            | CommandType::IconUnitOrArea
            | CommandType::IconUnitOrRectangle
    )
}
