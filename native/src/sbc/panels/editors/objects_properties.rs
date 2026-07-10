use spring_native::prelude::{Error, NativeInterfaceRef};

use crate::sbc::command_system::model::Models;
use crate::sbc::envelope::envelope_fields;
use crate::sbc::objects::{ObjectKind, ObjectManager, SelectionManager};
use crate::sbc::panels::editor::Editor;
use crate::sbc::panels::editor_base::{group_rml, resolve_base, section_rml, FieldSet};
use crate::sbc::panels::field::{ChangeQueue, FieldValue, InteractionQueue};
use crate::sbc::panels::fields::NumericField;
use crate::sbc::panels::registry::{EditorSpec, Tab};

// Mirrors ObjectPropertyWindow:Register in scen_edit/view/object/object_property_window.lua.
inventory::submit! {
    EditorSpec {
        name: "objectPropertyWindow",
        tab: Tab::Objects,
        order: 2,
        caption: "Properties",
        tooltip: "Edit object properties",
        image: "LuaUI/images/scenedit/anatomy.png",
        make: || Box::new(PropertiesView::new()),
    }
}

/// The core object properties: position, heading and health. Lua also exposes
/// per-def state fields, rules and unit commands; those need much more UI (a
/// rules editor, command lists) and are not ported.
///
/// Edits the primary selected object, following the selection as it changes.
pub(crate) struct PropertiesView {
    fields: FieldSet,
    selected: Option<(ObjectKind, i32)>,
    selection_revision: u64,
}

const NUMERIC: &[&str] = &["posx", "posy", "posz", "heading", "health"];

impl PropertiesView {
    pub(crate) fn new() -> Self {
        PropertiesView {
            fields: FieldSet::new(vec![
                Box::new(NumericField::new("posx", "X", 0.0).decimals(0).step(1.0)),
                Box::new(NumericField::new("posy", "Y", 0.0).decimals(0).step(1.0)),
                Box::new(NumericField::new("posz", "Z", 0.0).decimals(0).step(1.0)),
                Box::new(
                    NumericField::new("heading", "Heading", 0.0)
                        .decimals(0)
                        .step(1.0),
                ),
                Box::new(
                    NumericField::new("health", "Health", 0.0)
                        .decimals(0)
                        .step(1.0),
                ),
            ]),
            selected: None,
            selection_revision: u64::MAX,
        }
    }

    /// The command setting one field on the selected object. Position writes the
    /// whole `pos`, heading a `dir`, health the `health` field.
    fn commit(&self, base: &str, next: &mut u64) -> Vec<String> {
        let Some((kind, model_id)) = self.selected else {
            return vec![];
        };
        let key_value = match base {
            "posx" | "posy" | "posz" => (
                "pos".to_string(),
                serde_json::json!({
                    "x": self.fields.number("posx"),
                    "y": self.fields.number("posy"),
                    "z": self.fields.number("posz"),
                }),
            ),
            "heading" => {
                let radians = self.fields.number("heading").to_radians();
                (
                    "dir".to_string(),
                    serde_json::json!({ "x": radians.sin(), "y": 0.0, "z": radians.cos() }),
                )
            }
            "health" => (
                "health".to_string(),
                serde_json::json!(self.fields.number("health")),
            ),
            _ => return vec![],
        };
        vec![envelope_fields(
            "SetObjectParamCommand",
            next,
            serde_json::json!({
                "objType": kind_wire(kind),
                "modelID": model_id,
                "key": key_value.0,
                "value": key_value.1,
            }),
        )]
    }
}

fn kind_wire(kind: ObjectKind) -> &'static str {
    match kind {
        ObjectKind::Unit => "unit",
        ObjectKind::Feature => "feature",
        ObjectKind::Area => "area",
    }
}

impl Editor for PropertiesView {
    fn generate_rml(&self) -> String {
        if self.selected.is_none() {
            return r#"<div class="field-row"><span class="field-label">No object selected.</span></div>"#.to_string();
        }
        let mut h = section_rml("Position");
        h.push_str(&group_rml(&[
            self.fields.rml("posx"),
            self.fields.rml("posy"),
            self.fields.rml("posz"),
        ]));
        h.push_str(&section_rml("Orientation"));
        h.push_str(&self.fields.rml("heading"));
        h.push_str(&section_rml("State"));
        h.push_str(&self.fields.rml("health"));
        h
    }

    fn bind_fields(
        &mut self,
        interface: &NativeInterfaceRef,
        document: u64,
        changes: &ChangeQueue,
        interactions: &InteractionQueue,
    ) -> Result<(), Error> {
        self.fields.bind(interface, document, changes, interactions)
    }

    fn write_field_values(&self, interface: &NativeInterfaceRef) -> Result<(), Error> {
        self.fields.write_values(interface)
    }

    fn process_change(
        &mut self,
        name: &str,
        interface: &NativeInterfaceRef,
        next: &mut u64,
    ) -> Vec<String> {
        let base = resolve_base(name).to_string();
        if !NUMERIC.contains(&base.as_str()) {
            return vec![];
        }
        self.fields.read(&base, interface);
        self.commit(&base, next)
    }

    fn process_drag_end(&mut self, name: &str, next: &mut u64) -> Vec<String> {
        let base = resolve_base(name).to_string();
        self.commit(&base, next)
    }

    /// Whether the selection changed since the last look: cheap, runs each tick.
    fn wants_refresh(&mut self, models: &mut Models) -> bool {
        models.get::<SelectionManager>().revision() != self.selection_revision
    }

    /// The layout differs between "no selection" and "an object", so a change of
    /// whether anything is selected must regenerate the markup.
    fn wants_rebuild(&self) -> bool {
        true
    }

    /// Follow the primary selection and read the object's current values.
    fn refresh_from_engine(&mut self, _interface: &NativeInterfaceRef, models: &mut Models) {
        self.selection_revision = models.get::<SelectionManager>().revision();
        self.selected = models.get::<SelectionManager>().primary();

        let Some((kind, model_id)) = self.selected else {
            return;
        };
        let objects = models.get::<ObjectManager>();
        if let Some(pos) = objects.field_json(kind, model_id, "pos") {
            self.fields.set("posx", number(&pos["x"]));
            self.fields.set("posy", number(&pos["y"]));
            self.fields.set("posz", number(&pos["z"]));
        }
        if let Some(dir) = objects.field_json(kind, model_id, "dir") {
            let heading = number_f(&dir["x"]).atan2(number_f(&dir["z"])).to_degrees();
            self.fields.set("heading", FieldValue::Number(heading));
        }
        if let Some(health) = objects.field_json(kind, model_id, "health") {
            self.fields.set("health", number(&health));
        }
    }

    fn drag_field(&mut self, name: &str, dx: f32, interface: &NativeInterfaceRef) -> bool {
        self.fields.drag(name, dx, interface)
    }

    fn drag_end_field(&mut self, name: &str, interface: &NativeInterfaceRef) -> bool {
        self.fields.drag_end(name, interface)
    }

    fn begin_edit_field(&mut self, name: &str, interface: &NativeInterfaceRef) {
        self.fields.begin_edit(name, interface)
    }

    fn cancel_edit_field(&mut self, name: &str, interface: &NativeInterfaceRef) {
        self.fields.cancel_edit(name, interface)
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

fn number(value: &serde_json::Value) -> FieldValue {
    FieldValue::Number(number_f(value))
}

fn number_f(value: &serde_json::Value) -> f32 {
    value.as_f64().unwrap_or(0.0) as f32
}
