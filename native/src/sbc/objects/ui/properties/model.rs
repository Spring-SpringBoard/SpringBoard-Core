use crate::sbc::command_system::command::Command;
use crate::sbc::objects::{
    FieldRange, FieldValueType, ObjectFieldDescriptor, ObjectKind, ObjectManager,
    SetObjectParamCommand,
};
use crate::sbc::panels::field::{Field, FieldValue};
use crate::sbc::panels::fields::{BooleanField, ChoiceField, NumericField, StringField};
use crate::sbc::panels::runtime::{EditorModel, FieldMut, FieldRef};

#[derive(Clone, Copy)]
pub(super) struct Position {
    x: f32,
    y: f32,
    z: f32,
}

pub(super) struct SelectedObject {
    pub(super) kind: ObjectKind,
    pub(super) model_id: i32,
    pub(super) position: Option<Position>,
}

impl Position {
    pub(super) fn from_json(value: &serde_json::Value) -> Option<Self> {
        value.as_object().map(|_| Self {
            x: number_f(&value["x"]),
            y: number_f(&value["y"]),
            z: number_f(&value["z"]),
        })
    }

    pub(super) fn average(selection: &[SelectedObject], kind: ObjectKind) -> Option<Self> {
        let positions: Vec<_> = selection
            .iter()
            .filter(|object| object.kind == kind)
            .filter_map(|object| object.position)
            .collect();
        let count = positions.len() as f32;
        (count > 0.0).then(|| Self {
            x: positions.iter().map(|position| position.x).sum::<f32>() / count,
            y: positions.iter().map(|position| position.y).sum::<f32>() / count,
            z: positions.iter().map(|position| position.z).sum::<f32>() / count,
        })
    }

    fn from_fields(model: &PropertiesModel, field: &str) -> Self {
        Self {
            x: model.number(&component_name(field, "x")),
            y: model.number(&component_name(field, "y")),
            z: model.number(&component_name(field, "z")),
        }
    }

    fn plus(self, delta: Self) -> Self {
        Self {
            x: self.x + delta.x,
            y: self.y + delta.y,
            z: self.z + delta.z,
        }
    }

    fn minus(self, other: Self) -> Self {
        Self {
            x: self.x - other.x,
            y: self.y - other.y,
            z: self.z - other.z,
        }
    }

    pub(super) fn json(self) -> serde_json::Value {
        serde_json::json!({ "x": self.x, "y": self.y, "z": self.z })
    }
}

#[derive(Clone)]
pub(super) enum PropertyLayout {
    Field(String),
    Group(Vec<String>),
    Section(String),
}

/// `rot` is stored in radians but edited in degrees, as in Lua.
pub(super) fn is_angle(field: &str) -> bool {
    field == "rot"
}

/// A sub-object's field, named `parent.key` (Lua's `name .. tkey`).
fn sub_name(parent: &str, key: &str) -> String {
    format!("{parent}.{key}")
}

pub(super) fn sub_parts(name: &str) -> Option<(&str, &str)> {
    name.split_once('.')
}

/// Lua sends only the changed key for these, rather than the whole table: the
/// setters apply the keys they are given, and resending the rest would fight
/// with the engine's own bookkeeping.
fn sends_single_key(parent: &str) -> bool {
    matches!(parent, "states" | "rules")
}

/// These composites have a dedicated Collision editor. Chili deliberately hid
/// them from Properties so the generic editor did not duplicate the collision
/// volume controls and, especially, its blocking toggles.
fn belongs_to_collision_editor(name: &str) -> bool {
    matches!(
        name,
        "collision" | "blocking" | "radiusHeight" | "midAimPos"
    )
}

/// Edits the primary selected object, applying compatible changes to the whole
/// selection. Position is displayed as the selection's average and edited as a
/// shared offset, matching Chili's ObjectPropertyWindow.
///
/// The model is genuinely dynamic — its fields are discovered from the selected
/// object — so its IDs are indexes into the field list, not an enum.
pub(crate) struct PropertiesModel {
    pub(super) fields: Vec<Box<dyn Field>>,
    pub(super) layout: Vec<PropertyLayout>,
    pub(super) selected: Option<(ObjectKind, i32)>,
    pub(super) selection: Vec<SelectedObject>,
    pub(super) average_position: Option<Position>,
    pub(super) selection_revision: u64,
    /// The object the current fields were built for; a different object may have
    /// different sub-object keys.
    pub(super) fields_for: Option<(ObjectKind, i32)>,
    pub(super) teams: Vec<(i32, String)>,
}

impl PropertiesModel {
    pub(crate) fn new() -> Self {
        PropertiesModel {
            fields: Vec::new(),
            layout: Vec::new(),
            selected: None,
            selection: Vec::new(),
            average_position: None,
            selection_revision: u64::MAX,
            fields_for: None,
            teams: Vec::new(),
        }
    }

    fn value(&self, name: &str) -> FieldValue {
        self.fields
            .iter()
            .find(|field| field.name() == name)
            .map(|field| field.value())
            .unwrap_or(FieldValue::Text(String::new()))
    }

    pub(super) fn set(&mut self, name: &str, value: FieldValue) {
        if let Some(field) = self.fields.iter_mut().find(|field| field.name() == name) {
            field.set_value(&value);
        }
    }

    fn number(&self, name: &str) -> f32 {
        match self.value(name) {
            FieldValue::Number(n) => n,
            _ => 0.0,
        }
    }

    /// Build the fields for one object.
    ///
    /// Generic sub-objects (`states`, `resources`, ...) and the rules map have
    /// no fixed shape, so their keys are discovered from the object's own
    /// value, exactly as Lua walks the s11n table. Collision composites belong
    /// exclusively to Collision and are skipped below.
    pub(super) fn rebuild_fields(
        &mut self,
        kind: ObjectKind,
        model_id: i32,
        descriptors: Vec<ObjectFieldDescriptor>,
        objects: &mut ObjectManager,
        teams: &[(i32, String)],
    ) {
        let mut fields: Vec<Box<dyn Field>> = Vec::new();
        let mut layout = Vec::new();
        let mut descriptors = descriptors;
        descriptors.sort_by_key(|d| descriptor_order(d.name));

        for descriptor in descriptors {
            let name = descriptor.name;
            if belongs_to_collision_editor(name) {
                continue;
            }
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
                            fields.push(Box::new(
                                NumericField::new(&field, axis.to_uppercase(), 0.0)
                                    .decimals(2)
                                    .step(1.0)
                                    .compact(),
                            ) as Box<dyn Field>);
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

        self.fields = fields;
        self.layout = layout;
        self.fields_for = Some((kind, model_id));
    }

    /// Commands setting one field on every selected object of the primary
    /// object's kind. A position component is special: its displayed value is
    /// the selection average, so changing it translates each selected object
    /// by the same delta instead of stacking every object on one coordinate.
    pub(super) fn commit(&self, base: &str) -> Vec<Box<dyn Command>> {
        let Some((kind, model_id)) = self.selected else {
            return vec![];
        };

        if let Some((field, _)) = component(base) {
            if field == "pos" {
                let desired = Position::from_fields(self, field);
                let average = self.average_position.unwrap_or(desired);
                let delta = desired.minus(average);
                return self
                    .selection
                    .iter()
                    .filter(|object| object.kind == kind)
                    .filter_map(|object| {
                        object.position.map(|position| {
                            Box::new(SetObjectParamCommand::new(
                                object.kind,
                                object.model_id,
                                serde_json::Value::String(field.to_string()),
                                position.plus(delta).json(),
                            )) as Box<dyn Command>
                        })
                    })
                    .collect();
            }
        }

        let (key, value): (&str, serde_json::Value) = if let Some((field, _)) = component(base) {
            // A vector is set whole, from its three axis fields.
            let axis = |axis: &str| {
                let value = self.number(&component_name(field, axis));
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
            let value = match self.value(base) {
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

        let targets: Vec<_> = self
            .selection
            .iter()
            .filter(|object| object.kind == kind)
            .collect();
        if targets.is_empty() {
            return vec![Box::new(SetObjectParamCommand::new(
                kind,
                model_id,
                serde_json::Value::String(key.to_string()),
                value,
            ))];
        }
        targets
            .into_iter()
            .map(|object| {
                Box::new(SetObjectParamCommand::new(
                    object.kind,
                    object.model_id,
                    serde_json::Value::String(key.to_string()),
                    value.clone(),
                )) as Box<dyn Command>
            })
            .collect()
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
        match self.value(name) {
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

    pub(super) fn set_json_field(&mut self, name: &str, value: &serde_json::Value) {
        // The team choice shows names, so the stored id has to be mapped back.
        if name == "team" {
            if let Some(team) = value.as_i64().and_then(|id| self.team_name(id as i32)) {
                self.set(name, FieldValue::Text(team));
            }
            return;
        }
        if let Some(value) = value.as_bool() {
            self.set(name, FieldValue::Bool(value));
        } else if let Some(value) = value.as_str() {
            self.set(name, FieldValue::Text(value.to_string()));
        } else if value.is_number() {
            self.set(name, number(value));
        }
    }

    /// The reverse of `sub_value`: put a sub-object key into its field.
    pub(super) fn set_sub_field(&mut self, name: &str, key: &str, value: &serde_json::Value) {
        let captions = match key {
            "fireState" => Some(FIRE_STATES),
            "moveState" => Some(MOVE_STATES),
            _ => None,
        };
        if let Some(captions) = captions {
            let index = value.as_i64().unwrap_or(0) as usize;
            if let Some(caption) = captions.get(index) {
                self.set(name, FieldValue::Text((*caption).to_string()));
            }
            return;
        }
        self.set_json_field(name, value);
    }
}

impl EditorModel for PropertiesModel {
    type Id = usize;

    fn fields(&self) -> Vec<FieldRef<'_>> {
        self.fields
            .iter()
            .map(|field| FieldRef {
                field: field.as_ref(),
                brush: None,
            })
            .collect()
    }

    fn fields_mut(&mut self) -> Vec<FieldMut<'_>> {
        self.fields
            .iter_mut()
            .map(|field| FieldMut {
                field: field.as_mut(),
                brush: None,
            })
            .collect()
    }

    fn id_of(&self, name: &str) -> Option<usize> {
        self.fields.iter().position(|field| field.name() == name)
    }

    fn name_of(&self, id: usize) -> String {
        self.fields
            .get(id)
            .map(|field| field.name().to_string())
            .unwrap_or_default()
    }
}

fn number(value: &serde_json::Value) -> FieldValue {
    FieldValue::Number(number_f(value))
}

pub(super) fn number_f(value: &serde_json::Value) -> f32 {
    value.as_f64().unwrap_or(0.0) as f32
}

fn index_of(captions: &[&str], value: &str) -> i32 {
    captions
        .iter()
        .position(|caption| *caption == value)
        .unwrap_or(0) as i32
}

fn numeric_field(descriptor: &ObjectFieldDescriptor) -> Box<dyn Field> {
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
fn sub_field(name: &str, key: &str, value: &serde_json::Value) -> Option<Box<dyn Field>> {
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

pub(super) fn component_name(field: &str, axis: &str) -> String {
    format!("{field}_{axis}")
}

pub(super) fn component(name: &str) -> Option<(&str, &str)> {
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

#[cfg(test)]
mod tests {
    use super::belongs_to_collision_editor;

    #[test]
    fn collision_composites_do_not_belong_in_properties() {
        for name in ["collision", "blocking", "radiusHeight", "midAimPos"] {
            assert!(belongs_to_collision_editor(name));
        }
        assert!(!belongs_to_collision_editor("states"));
    }
}
