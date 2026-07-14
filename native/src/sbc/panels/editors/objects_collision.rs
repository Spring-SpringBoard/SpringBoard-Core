use std::cell::RefCell;
use std::rc::Rc;

use spring_native::prelude::{Error, NativeInterfaceRef};

use crate::sbc::command_system::command::Command;
use crate::sbc::command_system::model::Models;
use crate::sbc::objects::{ObjectKind, ObjectManager, SelectionManager, SetObjectParamCommand};
use crate::sbc::panels::editor::Editor;
use crate::sbc::panels::editor_base::{resolve_base, FieldSet, Layout};
use crate::sbc::panels::field::{ChangeQueue, FieldValue, InteractionQueue};
use crate::sbc::panels::fields::{BooleanField, ChoiceField, NumericField};
use crate::sbc::panels::registry::{EditorSpec, Tab};
use crate::sbc::rml::element_by_id;

// Mirrors CollisionView:Register in scen_edit/view/object/collision_window.lua.
inventory::submit! {
    EditorSpec {
        name: "collisionView",
        tab: Tab::Objects,
        order: 3,
        caption: "Collision",
        tooltip: "Edit collision volumes",
        image: "LuaUI/images/scenedit/boulder-dash.png",
        make: || Box::new(CollisionView::new()),
    }
}

/// Collision volume editor for the selected unit or feature.
///
/// Ports `scen_edit/view/object/collision_window.lua`. The engine stores four
/// composite objects — `collision` (scale/offset/type/axis), `radiusHeight`,
/// `midAimPos`, and `blocking` — which this editor decomposes into individual
/// fields and re-bundles on change.
///
/// Cross-field coupling (faithful to the Lua original):
/// - **Sphere** syncs all three scales and hides scale Y/Z + axis.
/// - **Cylinder** links two scales based on the chosen axis.
/// - **Box** hides the axis field.
pub(crate) struct CollisionView {
    fields: FieldSet,
    selected: Option<(ObjectKind, i32)>,
    selection_revision: u64,
    /// Engine-side testType; not user-editable, but must be preserved in writes.
    test_type: i32,
    document: Option<u64>,
    show_vol_clicked: Rc<RefCell<bool>>,
}

impl CollisionView {
    pub(crate) fn new() -> Self {
        CollisionView {
            fields: FieldSet::new(vec![
                Box::new(ChoiceField::new(
                    "vType",
                    "Type",
                    vec![
                        "Cylinder".to_string(),
                        "Box".to_string(),
                        "Sphere".to_string(),
                    ],
                )),
                Box::new(ChoiceField::new(
                    "axis",
                    "Axis",
                    vec!["X".to_string(), "Y".to_string(), "Z".to_string()],
                )),
                // Scale
                Box::new(
                    NumericField::new("scaleX", "X", 1.0)
                        .decimals(0)
                        .step(1.0)
                        .min(0.0),
                ),
                Box::new(
                    NumericField::new("scaleY", "Y", 1.0)
                        .decimals(0)
                        .step(1.0)
                        .min(0.0),
                ),
                Box::new(
                    NumericField::new("scaleZ", "Z", 1.0)
                        .decimals(0)
                        .step(1.0)
                        .min(0.0),
                ),
                // Offset
                Box::new(NumericField::new("offsetX", "X", 0.0).decimals(0).step(1.0)),
                Box::new(NumericField::new("offsetY", "Y", 0.0).decimals(0).step(1.0)),
                Box::new(NumericField::new("offsetZ", "Z", 0.0).decimals(0).step(1.0)),
                // Radius / Height
                Box::new(
                    NumericField::new("radius", "Radius", 0.0)
                        .decimals(0)
                        .step(1.0)
                        .min(0.0),
                ),
                Box::new(
                    NumericField::new("height", "Height", 0.0)
                        .decimals(0)
                        .step(1.0)
                        .min(0.0)
                        .max(256.0),
                ),
                // Center (mid pos)
                Box::new(NumericField::new("mpx", "X", 0.0).decimals(0).step(1.0)),
                Box::new(NumericField::new("mpy", "Y", 0.0).decimals(0).step(1.0)),
                Box::new(NumericField::new("mpz", "Z", 0.0).decimals(0).step(1.0)),
                // Aim pos
                Box::new(NumericField::new("apx", "X", 0.0).decimals(0).step(1.0)),
                Box::new(NumericField::new("apy", "Y", 0.0).decimals(0).step(1.0)),
                Box::new(NumericField::new("apz", "Z", 0.0).decimals(0).step(1.0)),
                // Blocking
                Box::new(BooleanField::new("isBlocking", "Blocking", true)),
                Box::new(BooleanField::new(
                    "isSolidObjectCollidable",
                    "Solid object collidable",
                    true,
                )),
                Box::new(BooleanField::new(
                    "isProjectileCollidable",
                    "Projectile collidable",
                    true,
                )),
                Box::new(BooleanField::new(
                    "isRaySegmentCollidable",
                    "Ray segment collidable",
                    true,
                )),
                Box::new(BooleanField::new("crushable", "Crushable", true)),
                Box::new(BooleanField::new(
                    "blockEnemyPushing",
                    "Block enemy pushing",
                    true,
                )),
                Box::new(BooleanField::new(
                    "blockHeightChanges",
                    "Block height changes",
                    true,
                )),
            ]),
            selected: None,
            selection_revision: u64::MAX,
            test_type: 1,
            document: None,
            show_vol_clicked: Rc::new(RefCell::new(false)),
        }
    }

    /// Toggle the `hidden` class on scale Y/Z and axis wrappers, matching the
    /// Lua `SetInvisibleFields` calls. Called after bind, after refresh, and
    /// when the user changes vType.
    fn apply_visibility(&self, interface: &NativeInterfaceRef) {
        let Some(doc) = self.document else {
            return;
        };
        let vtype = self.fields.text("vType");
        let hide_axis = matches!(vtype.as_str(), "Sphere" | "Box");
        let hide_scale_yz = vtype == "Sphere";

        for (name, hide) in [
            ("scaleY", hide_scale_yz),
            ("scaleZ", hide_scale_yz),
            ("axis", hide_axis),
        ] {
            if let Some(elem) = element_by_id(interface, doc, &format!("row-{name}")) {
                let _ = interface.rml_ui().element_set_class(elem, "hidden", hide);
            }
        }
    }

    /// Sync linked scale fields when vType is Sphere or Cylinder, mirroring the
    /// Lua `OnFieldChange` coupling logic.
    fn sync_linked_scales(&mut self, base: &str) {
        if !is_scale_field(base) {
            return;
        }
        let vtype = self.fields.text("vType");
        let value = self.fields.number(base);

        if vtype == "Sphere" {
            for name in &["scaleX", "scaleY", "scaleZ"] {
                self.fields.set(name, FieldValue::Number(value));
            }
        } else if vtype == "Cylinder" {
            let axis = self.fields.text("axis");
            let linked = match (axis.as_str(), base) {
                ("X", "scaleX") => Some("scaleZ"),
                ("X", "scaleZ") => Some("scaleX"),
                ("Y", "scaleX") => Some("scaleY"),
                ("Y", "scaleY") => Some("scaleX"),
                ("Z", "scaleY") => Some("scaleZ"),
                ("Z", "scaleZ") => Some("scaleY"),
                _ => None,
            };
            if let Some(other) = linked {
                self.fields.set(other, FieldValue::Number(value));
            }
        }
    }

    /// Build the command for a field change, bundling scalar fields back into
    /// the composite objects the engine expects.
    fn commit(&self, base: &str) -> Vec<Box<dyn Command>> {
        let Some((kind, model_id)) = self.selected else {
            return vec![];
        };

        let (key, value): (&str, serde_json::Value) = if is_collision_field(base) {
            (
                "collision",
                serde_json::json!({
                    "scaleX": self.fields.number("scaleX"),
                    "scaleY": self.fields.number("scaleY"),
                    "scaleZ": self.fields.number("scaleZ"),
                    "offsetX": self.fields.number("offsetX"),
                    "offsetY": self.fields.number("offsetY"),
                    "offsetZ": self.fields.number("offsetZ"),
                    "vType": vtype_to_int(&self.fields.text("vType")),
                    "testType": self.test_type,
                    "axis": axis_to_int(&self.fields.text("axis")),
                }),
            )
        } else if matches!(base, "radius" | "height") {
            (
                "radiusHeight",
                serde_json::json!({
                    "radius": self.fields.number("radius"),
                    "height": self.fields.number("height"),
                }),
            )
        } else if is_mid_aim_field(base) {
            (
                "midAimPos",
                serde_json::json!({
                    "mid": {
                        "x": self.fields.number("mpx"),
                        "y": self.fields.number("mpy"),
                        "z": self.fields.number("mpz"),
                    },
                    "aim": {
                        "x": self.fields.number("apx"),
                        "y": self.fields.number("apy"),
                        "z": self.fields.number("apz"),
                    },
                }),
            )
        } else if is_blocking_field(base) {
            (
                "blocking",
                serde_json::json!({
                    "isBlocking": bool_field(&self.fields, "isBlocking"),
                    "isSolidObjectCollidable": bool_field(&self.fields, "isSolidObjectCollidable"),
                    "isProjectileCollidable": bool_field(&self.fields, "isProjectileCollidable"),
                    "isRaySegmentCollidable": bool_field(&self.fields, "isRaySegmentCollidable"),
                    "crushable": bool_field(&self.fields, "crushable"),
                    "blockEnemyPushing": bool_field(&self.fields, "blockEnemyPushing"),
                    "blockHeightChanges": bool_field(&self.fields, "blockHeightChanges"),
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

impl Editor for CollisionView {
    fn generate_rml(&self) -> String {
        if self.selected.is_none() {
            return r#"<div class="field-row"><span class="field-label">No object selected.</span></div>"#
                .to_string();
        }
        self.fields.generate_rml(&[
            Layout::Raw(
                r#"<div class="field-row"><button id="collision-show-vol" class="dialog-button" style="width: 200px;">Show volume</button></div>"#
                    .to_string(),
            ),
            Layout::Field("vType"),
            Layout::IdentifiedField("axis"),
            Layout::Section("Scale"),
            Layout::IdentifiedGroup(&["scaleX", "scaleY", "scaleZ"]),
            Layout::Section("Offset"),
            Layout::IdentifiedGroup(&["offsetX", "offsetY", "offsetZ"]),
            Layout::Section("Radius"),
            Layout::IdentifiedGroup(&["radius", "height"]),
            Layout::Section("Center"),
            Layout::IdentifiedGroup(&["mpx", "mpy", "mpz"]),
            Layout::Section("Aim"),
            Layout::IdentifiedGroup(&["apx", "apy", "apz"]),
            Layout::Section("Blocking"),
            Layout::Field("isBlocking"),
            Layout::Field("isSolidObjectCollidable"),
            Layout::Field("isProjectileCollidable"),
            Layout::Field("isRaySegmentCollidable"),
            Layout::Field("crushable"),
            Layout::Field("blockEnemyPushing"),
            Layout::Field("blockHeightChanges"),
        ])
    }

    fn bind_fields(
        &mut self,
        interface: &NativeInterfaceRef,
        document: u64,
        changes: &ChangeQueue,
        interactions: &InteractionQueue,
    ) -> Result<(), Error> {
        self.document = Some(document);
        self.fields
            .bind(interface, document, changes, interactions)?;

        if let Some(button) = element_by_id(interface, document, "collision-show-vol") {
            let flag = self.show_vol_clicked.clone();
            interface
                .rml_ui()
                .element_add_event_listener(button, "click", false, move || {
                    *flag.borrow_mut() = true;
                })?;
        }

        self.apply_visibility(interface);
        Ok(())
    }

    fn write_field_values(&self, interface: &NativeInterfaceRef) -> Result<(), Error> {
        self.fields.write_values(interface)
    }

    fn process_change(
        &mut self,
        name: &str,
        interface: &NativeInterfaceRef,
    ) -> Vec<Box<dyn Command>> {
        let base = resolve_base(name).to_string();
        self.fields.read(&base, interface);

        if base == "vType" {
            self.apply_visibility(interface);
        }

        self.sync_linked_scales(&base);

        if is_scale_field(&base) {
            let _ = self.fields.write_values(interface);
        }

        self.commit(&base)
    }

    fn process_drag_end(&mut self, name: &str) -> Vec<Box<dyn Command>> {
        let base = resolve_base(name).to_string();
        self.sync_linked_scales(&base);
        self.commit(&base)
    }

    fn tick(&mut self, interface: &NativeInterfaceRef, _document: u64) -> Vec<Box<dyn Command>> {
        if std::mem::take(&mut *self.show_vol_clicked.borrow_mut()) {
            let _ = interface.messages().send_commands("debugcolvol", "");
        }
        vec![]
    }

    fn wants_refresh(&mut self, models: &mut Models) -> bool {
        models.get::<SelectionManager>().revision() != self.selection_revision
    }

    fn wants_rebuild(&self) -> bool {
        true
    }

    fn refresh_from_engine(&mut self, interface: &NativeInterfaceRef, models: &mut Models) {
        self.selection_revision = models.get::<SelectionManager>().revision();
        self.selected = models.get::<SelectionManager>().primary();

        let Some((kind, model_id)) = self.selected else {
            return;
        };
        let objects = models.get::<ObjectManager>();

        if let Some(c) = objects.field_json(kind, model_id, "collision") {
            self.fields.set("scaleX", number(&c["scaleX"]));
            self.fields.set("scaleY", number(&c["scaleY"]));
            self.fields.set("scaleZ", number(&c["scaleZ"]));
            self.fields.set("offsetX", number(&c["offsetX"]));
            self.fields.set("offsetY", number(&c["offsetY"]));
            self.fields.set("offsetZ", number(&c["offsetZ"]));
            let vt = c["vType"].as_i64().unwrap_or(1) as i32;
            self.fields
                .set("vType", FieldValue::Text(vtype_from_int(vt).to_string()));
            let ax = c["axis"].as_i64().unwrap_or(1) as i32;
            self.fields
                .set("axis", FieldValue::Text(axis_from_int(ax).to_string()));
            self.test_type = c["testType"].as_i64().unwrap_or(1) as i32;
        }

        if let Some(rh) = objects.field_json(kind, model_id, "radiusHeight") {
            self.fields.set("radius", number(&rh["radius"]));
            self.fields.set("height", number(&rh["height"]));
        }

        if let Some(ma) = objects.field_json(kind, model_id, "midAimPos") {
            self.fields.set("mpx", number(&ma["mid"]["x"]));
            self.fields.set("mpy", number(&ma["mid"]["y"]));
            self.fields.set("mpz", number(&ma["mid"]["z"]));
            self.fields.set("apx", number(&ma["aim"]["x"]));
            self.fields.set("apy", number(&ma["aim"]["y"]));
            self.fields.set("apz", number(&ma["aim"]["z"]));
        }

        if let Some(b) = objects.field_json(kind, model_id, "blocking") {
            self.fields.set(
                "isBlocking",
                FieldValue::Bool(b["isBlocking"].as_bool().unwrap_or(true)),
            );
            self.fields.set(
                "isSolidObjectCollidable",
                FieldValue::Bool(b["isSolidObjectCollidable"].as_bool().unwrap_or(true)),
            );
            self.fields.set(
                "isProjectileCollidable",
                FieldValue::Bool(b["isProjectileCollidable"].as_bool().unwrap_or(true)),
            );
            self.fields.set(
                "isRaySegmentCollidable",
                FieldValue::Bool(b["isRaySegmentCollidable"].as_bool().unwrap_or(true)),
            );
            self.fields.set(
                "crushable",
                FieldValue::Bool(b["crushable"].as_bool().unwrap_or(true)),
            );
            self.fields.set(
                "blockEnemyPushing",
                FieldValue::Bool(b["blockEnemyPushing"].as_bool().unwrap_or(true)),
            );
            self.fields.set(
                "blockHeightChanges",
                FieldValue::Bool(b["blockHeightChanges"].as_bool().unwrap_or(true)),
            );
        }

        self.apply_visibility(interface);
    }

    fn drag_field(&mut self, name: &str, dx: f32, interface: &NativeInterfaceRef) -> bool {
        let handled = self.fields.drag(name, dx, interface);
        if handled {
            let base = resolve_base(name);
            self.sync_linked_scales(base);
            let _ = self.fields.write_values(interface);
        }
        handled
    }

    fn drag_end_field(&mut self, name: &str, interface: &NativeInterfaceRef) -> bool {
        self.fields.drag_end(name, interface)
    }

    fn begin_edit_field(&mut self, name: &str, interface: &NativeInterfaceRef) {
        self.fields.begin_edit(name, interface);
    }

    fn cancel_edit_field(&mut self, name: &str, interface: &NativeInterfaceRef) {
        self.fields.cancel_edit(name, interface);
    }

    fn field_value(&self, name: &str) -> FieldValue {
        self.fields.value(name)
    }

    fn set_field_value(&mut self, name: &str, value: FieldValue, interface: &NativeInterfaceRef) {
        self.fields.set(resolve_base(name), value);
        let _ = self.fields.write_values(interface);
    }

    fn field_asset(&self, _name: &str) -> Option<(String, Vec<String>)> {
        None
    }
}

// ── helpers ───────────────────────────────────────────────────────

fn is_scale_field(name: &str) -> bool {
    matches!(name, "scaleX" | "scaleY" | "scaleZ")
}

fn is_collision_field(name: &str) -> bool {
    matches!(
        name,
        "scaleX" | "scaleY" | "scaleZ" | "offsetX" | "offsetY" | "offsetZ" | "vType" | "axis"
    )
}

fn is_mid_aim_field(name: &str) -> bool {
    matches!(name, "mpx" | "mpy" | "mpz" | "apx" | "apy" | "apz")
}

fn is_blocking_field(name: &str) -> bool {
    matches!(
        name,
        "isBlocking"
            | "isSolidObjectCollidable"
            | "isProjectileCollidable"
            | "isRaySegmentCollidable"
            | "crushable"
            | "blockEnemyPushing"
            | "blockHeightChanges"
    )
}

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

fn bool_field(fields: &FieldSet, name: &str) -> bool {
    matches!(fields.value(name), FieldValue::Bool(true))
}

fn number(value: &serde_json::Value) -> FieldValue {
    FieldValue::Number(value.as_f64().unwrap_or(0.0) as f32)
}
