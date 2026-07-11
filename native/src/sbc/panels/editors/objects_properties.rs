use spring_native::prelude::{Error, NativeInterfaceRef};

use crate::sbc::command_system::model::Models;
use crate::sbc::envelope::envelope_fields;
use crate::sbc::objects::{
    FieldRange, FieldValueType, ObjectFieldDescriptor, ObjectKind, ObjectManager, SelectionManager,
};
use crate::sbc::panels::editor::Editor;
use crate::sbc::panels::editor_base::{resolve_base, FieldSet, Layout};
use crate::sbc::panels::field::{ChangeQueue, FieldValue, InteractionQueue};
use crate::sbc::panels::fields::{BooleanField, ChoiceField, NumericField, StringField};
use crate::sbc::panels::registry::{EditorSpec, Tab};
use crate::sbc::teams::TeamManager;

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

/// Edits the primary selected object, following the selection as it changes.
pub(crate) struct PropertiesView {
    fields: FieldSet,
    layout: Vec<PropertyLayout>,
    selected: Option<(ObjectKind, i32)>,
    selection_revision: u64,
    /// The object the current fields were built for; a different object may have
    /// different sub-object keys.
    fields_for: Option<(ObjectKind, i32)>,
    teams: Vec<(i32, String)>,
}

#[derive(Clone)]
enum PropertyLayout {
    Field(String),
    Group(Vec<String>),
    Section(String),
}

/// `rot` is stored in radians but edited in degrees, as in Lua.
fn is_angle(field: &str) -> bool {
    field == "rot"
}

/// A sub-object's field, named `parent.key` (Lua's `name .. tkey`).
fn sub_name(parent: &str, key: &str) -> String {
    format!("{parent}.{key}")
}

fn sub_parts(name: &str) -> Option<(&str, &str)> {
    name.split_once('.')
}

/// Lua sends only the changed key for these, rather than the whole table: the
/// setters apply the keys they are given, and resending the rest would fight
/// with the engine's own bookkeeping.
fn sends_single_key(parent: &str) -> bool {
    matches!(parent, "states" | "rules")
}

impl PropertiesView {
    pub(crate) fn new() -> Self {
        PropertiesView {
            fields: FieldSet::new(Vec::new()),
            layout: Vec::new(),
            selected: None,
            selection_revision: u64::MAX,
            fields_for: None,
            teams: Vec::new(),
        }
    }

    /// Build the fields for one object.
    ///
    /// Sub-objects (`states`, `resources`, `collision`, ...) and the rules map
    /// have no fixed shape, so their keys are discovered from the object's own
    /// value, exactly as Lua walks the s11n table. Each becomes its own section.
    fn rebuild_fields(
        &mut self,
        kind: ObjectKind,
        model_id: i32,
        descriptors: Vec<ObjectFieldDescriptor>,
        objects: &mut ObjectManager,
        teams: &[(i32, String)],
    ) {
        let mut fields: Vec<Box<dyn crate::sbc::panels::field::Field>> = Vec::new();
        let mut layout = Vec::new();
        let mut descriptors = descriptors;
        descriptors.sort_by_key(|d| descriptor_order(d.name));

        for descriptor in descriptors {
            let name = descriptor.name;
            match descriptor.value_type {
                FieldValueType::Bool => {
                    fields.push(Box::new(BooleanField::new(name, &title(name), false)));
                    layout.push(PropertyLayout::Field(name.to_string()));
                }
                // The team is picked from the project's roster, not typed in.
                FieldValueType::Float | FieldValueType::Int if name == "team" => {
                    let captions = teams.iter().map(|(_, name)| name.clone()).collect();
                    fields.push(Box::new(ChoiceField::new(name, "Team", captions)));
                    layout.push(PropertyLayout::Field(name.to_string()));
                }
                FieldValueType::Float | FieldValueType::Int => {
                    fields.push(numeric_field(&descriptor));
                    layout.push(PropertyLayout::Field(name.to_string()));
                }
                FieldValueType::String => {
                    fields.push(Box::new(StringField::new(name, &title(name), "")));
                    layout.push(PropertyLayout::Field(name.to_string()));
                }
                FieldValueType::Vec3 | FieldValueType::Direction => {
                    layout.push(PropertyLayout::Section(title(name)));
                    let names = ["x", "y", "z"]
                        .into_iter()
                        .map(|axis| {
                            let field = component_name(name, axis);
                            fields.push(
                                NumericField::new(&field, axis.to_uppercase(), 0.0)
                                    .decimals(2)
                                    .step(1.0)
                                    .compact()
                                    .into_box(),
                            );
                            field
                        })
                        .collect();
                    layout.push(PropertyLayout::Group(names));
                }
                FieldValueType::Object(_) | FieldValueType::RulesMap => {
                    let Some(value) = objects.field_json(kind, model_id, name) else {
                        continue;
                    };
                    let Some(entries) = value.as_object() else {
                        continue;
                    };
                    // Build the rows first: a sub-object whose keys are all of a
                    // shape we cannot edit (a nested table) contributes nothing,
                    // and must not leave a bare section heading behind.
                    let mut rows: Vec<PropertyLayout> = Vec::new();
                    let mut row: Vec<String> = Vec::new();
                    for (key, value) in entries {
                        let field_name = sub_name(name, key);
                        let Some(field) = sub_field(&field_name, key, value) else {
                            continue;
                        };
                        fields.push(field);
                        row.push(field_name);
                        // Lua lays a table's keys out three to a row.
                        if row.len() == 3 {
                            rows.push(PropertyLayout::Group(std::mem::take(&mut row)));
                        }
                    }
                    if !row.is_empty() {
                        rows.push(PropertyLayout::Group(row));
                    }
                    if rows.is_empty() {
                        continue;
                    }
                    layout.push(PropertyLayout::Section(title(name)));
                    layout.extend(rows);
                }
                // A unit's command queue is not editable as a field.
                FieldValueType::CommandList => {}
            }
        }

        self.fields = FieldSet::new(fields);
        self.layout = layout;
        self.fields_for = Some((kind, model_id));
    }

    /// The command setting one field on the selected object.
    fn commit(&self, base: &str, next: &mut u64) -> Vec<String> {
        let Some((kind, model_id)) = self.selected else {
            return vec![];
        };

        let (key, value) = if let Some((field, _)) = component(base) {
            // A vector is set whole, from its three axis fields.
            let axis = |axis: &str| {
                let value = self.fields.number(&component_name(field, axis));
                if is_angle(field) {
                    value.to_radians()
                } else {
                    value
                }
            };
            (
                field,
                serde_json::json!({ "x": axis("x"), "y": axis("y"), "z": axis("z") }),
            )
        } else if let Some((parent, key)) = sub_parts(base) {
            let value = self.sub_value(base, key);
            if sends_single_key(parent) {
                // Only the key that changed: the setter merges it, and resending
                // the others would push back stale values.
                (parent, serde_json::json!({ key: value }))
            } else {
                // The whole table, rebuilt from every one of its fields.
                let mut table = serde_json::Map::new();
                for name in self.sub_fields_of(parent) {
                    let Some((_, key)) = sub_parts(&name) else {
                        continue;
                    };
                    table.insert(key.to_string(), self.sub_value(&name, key));
                }
                (parent, serde_json::Value::Object(table))
            }
        } else {
            let value = match self.fields.value(base) {
                FieldValue::Bool(value) => serde_json::json!(value),
                FieldValue::Number(value) => serde_json::json!(value),
                FieldValue::Text(value) if base == "team" => {
                    // The choice shows team names; the object stores the id.
                    serde_json::json!(self.team_id(&value))
                }
                FieldValue::Text(value) => serde_json::json!(value),
                FieldValue::Color(_) => return vec![],
            };
            (base, value)
        };

        vec![envelope_fields(
            "SetObjectParamCommand",
            next,
            serde_json::json!({
                "objType": kind_wire(kind),
                "modelID": model_id,
                "key": key,
                "value": value,
            }),
        )]
    }

    fn sub_fields_of(&self, parent: &str) -> Vec<String> {
        self.layout
            .iter()
            .flat_map(|row| match row {
                PropertyLayout::Group(names) => names.clone(),
                PropertyLayout::Field(name) => vec![name.clone()],
                PropertyLayout::Section(_) => Vec::new(),
            })
            .filter(|name| sub_parts(name).is_some_and(|(p, _)| p == parent))
            .collect()
    }

    /// A sub-object key's value, as the object stores it.
    fn sub_value(&self, name: &str, key: &str) -> serde_json::Value {
        match self.fields.value(name) {
            FieldValue::Bool(value) => serde_json::json!(value),
            FieldValue::Number(value) => serde_json::json!(value),
            // The state pick-lists show captions but store their index.
            FieldValue::Text(value) if key == "fireState" => {
                serde_json::json!(index_of(FIRE_STATES, &value))
            }
            FieldValue::Text(value) if key == "moveState" => {
                serde_json::json!(index_of(MOVE_STATES, &value))
            }
            FieldValue::Text(value) => serde_json::json!(value),
            FieldValue::Color(_) => serde_json::Value::Null,
        }
    }

    fn team_id(&self, name: &str) -> i32 {
        self.teams
            .iter()
            .find(|(_, team)| team == name)
            .map(|(id, _)| *id)
            .unwrap_or(0)
    }

    fn team_name(&self, id: i32) -> Option<String> {
        self.teams
            .iter()
            .find(|(team_id, _)| *team_id == id)
            .map(|(_, name)| name.clone())
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
        let mut layout = Vec::new();
        for row in &self.layout {
            match row {
                PropertyLayout::Field(name) => layout.push(Layout::FieldOwned(name.clone())),
                PropertyLayout::Group(names) => layout.push(Layout::GroupOwned(names.clone())),
                PropertyLayout::Section(caption) => {
                    layout.push(Layout::SectionOwned(caption.clone()))
                }
            }
        }
        self.fields.generate_rml(&layout)
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
        self.teams = models
            .get::<TeamManager>()
            .all_teams()
            .iter()
            .map(|team| (team.id, format!("Team {}", team.id)))
            .collect();

        let teams = self.teams.clone();
        let objects = models.get::<ObjectManager>();
        // A sub-object's keys come from the object itself, so the fields are
        // rebuilt for a new object, not just for a new kind.
        if self.fields_for != Some((kind, model_id)) {
            if let Some(descriptors) = objects.field_descriptors(kind) {
                self.rebuild_fields(kind, model_id, descriptors, objects, &teams);
            }
        }

        let objects = models.get::<ObjectManager>();
        for row in self.layout.clone() {
            match row {
                PropertyLayout::Field(name) => {
                    if let Some(value) = objects.field_json(kind, model_id, &name) {
                        self.set_json_field(&name, &value);
                    }
                }
                PropertyLayout::Group(names) => {
                    if let Some((field, _)) = names.first().and_then(|name| component(name)) {
                        if let Some(value) = objects.field_json(kind, model_id, field) {
                            for axis in ["x", "y", "z"] {
                                let mut component = number_f(&value[axis]);
                                if is_angle(field) {
                                    component = component.to_degrees();
                                }
                                self.fields.set(
                                    &component_name(field, axis),
                                    FieldValue::Number(component),
                                );
                            }
                        }
                        continue;
                    }
                    // A sub-object's row: read the parent once, then each key.
                    let Some((parent, _)) = names.first().and_then(|name| sub_parts(name)) else {
                        continue;
                    };
                    let Some(value) = objects.field_json(kind, model_id, parent) else {
                        continue;
                    };
                    for name in &names {
                        let Some((_, key)) = sub_parts(name) else {
                            continue;
                        };
                        self.set_sub_field(name, key, &value[key]);
                    }
                }
                PropertyLayout::Section(_) => {}
            }
        }
    }

    crate::sb_field_editor_methods!();
}

fn number(value: &serde_json::Value) -> FieldValue {
    FieldValue::Number(number_f(value))
}

fn number_f(value: &serde_json::Value) -> f32 {
    value.as_f64().unwrap_or(0.0) as f32
}

impl PropertiesView {
    fn set_json_field(&mut self, name: &str, value: &serde_json::Value) {
        // The team choice shows names, so the stored id has to be mapped back.
        if name == "team" {
            if let Some(team) = value.as_i64().and_then(|id| self.team_name(id as i32)) {
                self.fields.set(name, FieldValue::Text(team));
            }
            return;
        }
        if let Some(value) = value.as_bool() {
            self.fields.set(name, FieldValue::Bool(value));
        } else if let Some(value) = value.as_str() {
            self.fields.set(name, FieldValue::Text(value.to_string()));
        } else if value.is_number() {
            self.fields.set(name, number(value));
        }
    }

    /// The reverse of `sub_value`: put a sub-object key into its field.
    fn set_sub_field(&mut self, name: &str, key: &str, value: &serde_json::Value) {
        let captions = match key {
            "fireState" => Some(FIRE_STATES),
            "moveState" => Some(MOVE_STATES),
            _ => None,
        };
        if let Some(captions) = captions {
            let index = value.as_i64().unwrap_or(0) as usize;
            if let Some(caption) = captions.get(index) {
                self.fields
                    .set(name, FieldValue::Text((*caption).to_string()));
            }
            return;
        }
        self.set_json_field(name, value);
    }
}

fn index_of(captions: &[&str], value: &str) -> i32 {
    captions
        .iter()
        .position(|caption| *caption == value)
        .unwrap_or(0) as i32
}

trait BoxFieldExt {
    fn into_box(self) -> Box<dyn crate::sbc::panels::field::Field>;
}

impl BoxFieldExt for NumericField {
    fn into_box(self) -> Box<dyn crate::sbc::panels::field::Field> {
        Box::new(self)
    }
}

fn numeric_field(descriptor: &ObjectFieldDescriptor) -> Box<dyn crate::sbc::panels::field::Field> {
    let title = title(descriptor.name);
    let mut field = NumericField::new(descriptor.name, &title, 0.0)
        .decimals(if descriptor.value_type == FieldValueType::Int {
            0
        } else {
            2
        })
        .step(if descriptor.value_type == FieldValueType::Int {
            1.0
        } else {
            0.1
        });
    if let Some(FieldRange { min: Some(min), .. }) = descriptor.range {
        field = field.min(min as f32);
    }
    if let Some(FieldRange { max: Some(max), .. }) = descriptor.range {
        field = field.max(max as f32);
    }
    Box::new(field)
}

/// The captions Lua gives the two unit states that are pick-lists rather than
/// numbers.
const FIRE_STATES: &[&str] = &["Hold fire", "Return fire", "Fire at will"];
const MOVE_STATES: &[&str] = &["Hold position", "Maneuver", "Roam"];

/// One key of a sub-object, typed from the value the object actually holds.
fn sub_field(
    name: &str,
    key: &str,
    value: &serde_json::Value,
) -> Option<Box<dyn crate::sbc::panels::field::Field>> {
    let label = title(key);
    let choices = match key {
        "fireState" => Some(FIRE_STATES),
        "moveState" => Some(MOVE_STATES),
        _ => None,
    };
    if let Some(choices) = choices {
        let items = choices.iter().map(|c| (*c).to_string()).collect();
        return Some(Box::new(ChoiceField::new(name, &label, items)));
    }
    if value.is_boolean() {
        return Some(Box::new(BooleanField::new(name, &label, false)));
    }
    if value.is_number() {
        return Some(Box::new(
            NumericField::new(name, &label, 0.0).decimals(2).compact(),
        ));
    }
    if value.is_string() {
        return Some(Box::new(StringField::new(name, &label, "")));
    }
    None
}

fn component_name(field: &str, axis: &str) -> String {
    format!("{field}_{axis}")
}

fn component(name: &str) -> Option<(&str, &str)> {
    let (field, axis) = name.rsplit_once('_')?;
    matches!(axis, "x" | "y" | "z").then_some((field, axis))
}

fn title(name: &str) -> String {
    let mut out = String::new();
    for (i, ch) in name.chars().enumerate() {
        if i == 0 {
            out.push(ch.to_ascii_uppercase());
        } else if ch.is_ascii_uppercase() {
            out.push(' ');
            out.push(ch);
        } else {
            out.push(ch);
        }
    }
    out
}

fn descriptor_order(name: &str) -> usize {
    [
        "defName", "pos", "rot", "dir", "vel", "health", "mass", "maxRange",
    ]
    .iter()
    .position(|candidate| *candidate == name)
    .unwrap_or(usize::MAX)
}
