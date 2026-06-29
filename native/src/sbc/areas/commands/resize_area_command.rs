use serde::Deserialize;

use crate::sbc::command_system::command::Command;
use crate::sbc::command_system::context::Context;
use crate::sbc::command_system::registry::register_command;
use crate::sbc::objects::FieldValue;
use crate::sbc::objects::FieldValueType;
use crate::sbc::objects::ObjectKind;
use crate::sbc::objects::ObjectManager;
use crate::sbc::objects::Vec3;

/// Resizes an editor area. Mirrors
/// `scen_edit/command/resize_area_command.lua`, but applies through the native
/// area object model so widget sync follows the same path as object edits.
#[derive(Deserialize)]
pub struct ResizeAreaCommand {
    #[serde(rename = "areaID")]
    area_id: i32,
    x1: f32,
    z1: f32,
    x2: f32,
    z2: f32,

    #[serde(skip)]
    old: Option<Vec<FieldValue>>,
}

impl Command for ResizeAreaCommand {
    fn execute(&mut self, ctx: &mut Context) {
        if self.old.is_none() {
            self.old = Some(capture_area_fields(
                ctx.model::<ObjectManager>(),
                self.area_id,
            ));
        }
        let fields = self.new_area_fields();
        ctx.model::<ObjectManager>()
            .set_fields(ObjectKind::Area, self.area_id, &fields);
    }

    fn unexecute(&mut self, ctx: &mut Context) {
        if let Some(old) = &self.old {
            ctx.model::<ObjectManager>()
                .set_fields(ObjectKind::Area, self.area_id, old);
        }
    }
}

impl ResizeAreaCommand {
    fn new_area_fields(&self) -> Vec<FieldValue> {
        let width = (self.x2 - self.x1).abs();
        let depth = (self.z2 - self.z1).abs();
        let center_x = (self.x1 + self.x2) / 2.0;
        let center_z = (self.z1 + self.z2) / 2.0;

        vec![
            field_value(
                "pos",
                Vec3 {
                    x: center_x,
                    y: 0.0,
                    z: center_z,
                },
            ),
            field_value(
                "size",
                Vec3 {
                    x: width,
                    y: 0.0,
                    z: depth,
                },
            ),
        ]
    }
}

fn capture_area_fields(manager: &ObjectManager, area_id: i32) -> Vec<FieldValue> {
    ["pos", "size"]
        .into_iter()
        .filter_map(|name| {
            let descriptor = manager.descriptor(ObjectKind::Area, name)?;
            let value = manager.field_value(ObjectKind::Area, area_id, name)?;
            Some(FieldValue {
                name: descriptor.name,
                value_type: descriptor.value_type,
                value,
            })
        })
        .collect()
}

fn field_value(name: &'static str, value: Vec3) -> FieldValue {
    FieldValue {
        name,
        value_type: FieldValueType::Vec3,
        value: Box::new(value),
    }
}

register_command!(ResizeAreaCommand, "ResizeAreaCommand");
