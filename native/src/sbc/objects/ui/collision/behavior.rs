use spring_native::prelude::{Error, NativeInterfaceRef};

use crate::sbc::command_system::command::Command;
use crate::sbc::command_system::model::Models;
use crate::sbc::objects::{ObjectManager, SelectionManager, SetObjectParamCommand};
use crate::sbc::panels::field::{ChangeQueue, FieldValue, InteractionQueue};
use crate::sbc::panels::runtime::{Behavior, Event, Item, Outcome, Phase, Watch};
use crate::sbc::rml::element_by_id;

use super::layout;
use super::model::ColField::*;
use super::model::{
    ColField, CollisionModel, BLOCKING_FIELDS, COLLISION_FIELDS, MID_AIM_FIELDS, SCALES,
};

impl CollisionModel {
    /// Build the command for a field change, bundling scalar fields back into
    /// the composite objects the engine expects.
    fn commit(&self, id: ColField) -> Vec<Box<dyn Command>> {
        let Some((kind, model_id)) = self.selected else {
            return vec![];
        };

        let (key, value): (&str, serde_json::Value) = if COLLISION_FIELDS.contains(&id) {
            (
                "collision",
                serde_json::json!({
                    "scaleX": self.number(ScaleX),
                    "scaleY": self.number(ScaleY),
                    "scaleZ": self.number(ScaleZ),
                    "offsetX": self.number(OffsetX),
                    "offsetY": self.number(OffsetY),
                    "offsetZ": self.number(OffsetZ),
                    "vType": vtype_to_int(&self.text(VType)),
                    "testType": self.test_type,
                    "axis": axis_to_int(&self.text(Axis)),
                }),
            )
        } else if matches!(id, Radius | Height) {
            (
                "radiusHeight",
                serde_json::json!({
                    "radius": self.number(Radius),
                    "height": self.number(Height),
                }),
            )
        } else if MID_AIM_FIELDS.contains(&id) {
            (
                "midAimPos",
                serde_json::json!({
                    "mid": {
                        "x": self.number(MpX),
                        "y": self.number(MpY),
                        "z": self.number(MpZ),
                    },
                    "aim": {
                        "x": self.number(ApX),
                        "y": self.number(ApY),
                        "z": self.number(ApZ),
                    },
                }),
            )
        } else if BLOCKING_FIELDS.contains(&id) {
            (
                "blocking",
                serde_json::json!({
                    "isBlocking": self.boolean(IsBlocking),
                    "isSolidObjectCollidable": self.boolean(IsSolidObjectCollidable),
                    "isProjectileCollidable": self.boolean(IsProjectileCollidable),
                    "isRaySegmentCollidable": self.boolean(IsRaySegmentCollidable),
                    "crushable": self.boolean(Crushable),
                    "blockEnemyPushing": self.boolean(BlockEnemyPushing),
                    "blockHeightChanges": self.boolean(BlockHeightChanges),
                }),
            )
        } else {
            return vec![];
        };

        vec![Box::new(SetObjectParamCommand::new(
            kind,
            model_id,
            serde_json::Value::String(key.to_string()),
            value,
        ))]
    }
}

pub(crate) struct CollisionBehavior;

impl Behavior for CollisionBehavior {
    type Model = CollisionModel;

    fn layout(&self, model: &CollisionModel) -> Vec<Item<ColField>> {
        layout::layout(model)
    }

    fn watch(&mut self, model: &mut CollisionModel, models: &mut Models) -> Watch {
        if models.get::<SelectionManager>().revision() != model.selection_revision {
            Watch::Rebuild
        } else {
            Watch::Unchanged
        }
    }

    fn refresh(
        &mut self,
        model: &mut CollisionModel,
        engine: &NativeInterfaceRef,
        models: &mut Models,
    ) {
        model.selection_revision = models.get::<SelectionManager>().revision();
        model.selected = models.get::<SelectionManager>().primary();

        let Some((kind, model_id)) = model.selected else {
            return;
        };
        let objects = models.get::<ObjectManager>();

        if let Some(c) = objects.field_json(kind, model_id, "collision") {
            model.table.set(ScaleX, number(&c["scaleX"]));
            model.table.set(ScaleY, number(&c["scaleY"]));
            model.table.set(ScaleZ, number(&c["scaleZ"]));
            model.table.set(OffsetX, number(&c["offsetX"]));
            model.table.set(OffsetY, number(&c["offsetY"]));
            model.table.set(OffsetZ, number(&c["offsetZ"]));
            let vt = c["vType"].as_i64().unwrap_or(1) as i32;
            model
                .table
                .set(VType, FieldValue::Text(vtype_from_int(vt).to_string()));
            let ax = c["axis"].as_i64().unwrap_or(1) as i32;
            model
                .table
                .set(Axis, FieldValue::Text(axis_from_int(ax).to_string()));
            model.test_type = c["testType"].as_i64().unwrap_or(1) as i32;
        }

        if let Some(rh) = objects.field_json(kind, model_id, "radiusHeight") {
            model.table.set(Radius, number(&rh["radius"]));
            model.table.set(Height, number(&rh["height"]));
        }

        if let Some(ma) = objects.field_json(kind, model_id, "midAimPos") {
            model.table.set(MpX, number(&ma["mid"]["x"]));
            model.table.set(MpY, number(&ma["mid"]["y"]));
            model.table.set(MpZ, number(&ma["mid"]["z"]));
            model.table.set(ApX, number(&ma["aim"]["x"]));
            model.table.set(ApY, number(&ma["aim"]["y"]));
            model.table.set(ApZ, number(&ma["aim"]["z"]));
        }

        if let Some(b) = objects.field_json(kind, model_id, "blocking") {
            for (id, key) in [
                (IsBlocking, "isBlocking"),
                (IsSolidObjectCollidable, "isSolidObjectCollidable"),
                (IsProjectileCollidable, "isProjectileCollidable"),
                (IsRaySegmentCollidable, "isRaySegmentCollidable"),
                (Crushable, "crushable"),
                (BlockEnemyPushing, "blockEnemyPushing"),
                (BlockHeightChanges, "blockHeightChanges"),
            ] {
                model
                    .table
                    .set(id, FieldValue::Bool(b[key].as_bool().unwrap_or(true)));
            }
        }

        model.apply_visibility(engine);
    }

    fn apply(
        &mut self,
        event: Event<ColField>,
        model: &mut CollisionModel,
        engine: &NativeInterfaceRef,
    ) -> Outcome {
        let Event::Changed(id, phase) = event;

        if id == VType && phase == Phase::Commit {
            model.apply_visibility(engine);
        }

        model.sync_linked_scales(id);

        if SCALES.contains(&id) && phase == Phase::Commit {
            model.write_values(engine);
        }

        Outcome::commands(model.commit(id))
    }

    /// A scale drag must keep its linked scales moving on screen with it.
    fn dragged(&mut self, model: &mut CollisionModel, id: ColField, engine: &NativeInterfaceRef) {
        if !SCALES.contains(&id) {
            return;
        }
        model.sync_linked_scales(id);
        model.write_values(engine);
    }

    fn bind(
        &mut self,
        model: &mut CollisionModel,
        interface: &NativeInterfaceRef,
        document: u64,
        _changes: &ChangeQueue,
        _interactions: &InteractionQueue,
    ) -> Result<(), Error> {
        model.document = Some(document);
        if let Some(button) = element_by_id(interface, document, "collision-show-vol") {
            let flag = model.show_vol_clicked.clone();
            interface
                .rml_ui()
                .element_add_event_listener(button, "click", false, move || {
                    *flag.borrow_mut() = true;
                })?;
        }
        model.apply_visibility(interface);
        Ok(())
    }

    fn tick(
        &mut self,
        model: &mut CollisionModel,
        interface: &NativeInterfaceRef,
        _document: u64,
    ) -> Outcome {
        if std::mem::take(&mut *model.show_vol_clicked.borrow_mut()) {
            let _ = interface.messages().send_commands("debugcolvol", "");
        }
        Outcome::default()
    }
}

// ── helpers ───────────────────────────────────────────────────────

fn vtype_to_int(vtype: &str) -> i32 {
    match vtype {
        "Cylinder" => 1,
        "Box" => 2,
        "Sphere" => 3,
        _ => 1,
    }
}

fn vtype_from_int(v: i32) -> &'static str {
    match v {
        2 => "Box",
        3 => "Sphere",
        _ => "Cylinder",
    }
}

fn axis_to_int(axis: &str) -> i32 {
    match axis {
        "Y" => 2,
        "Z" => 3,
        _ => 1,
    }
}

fn axis_from_int(v: i32) -> &'static str {
    match v {
        2 => "Y",
        3 => "Z",
        _ => "X",
    }
}

fn number(value: &serde_json::Value) -> FieldValue {
    FieldValue::Number(value.as_f64().unwrap_or(0.0) as f32)
}
