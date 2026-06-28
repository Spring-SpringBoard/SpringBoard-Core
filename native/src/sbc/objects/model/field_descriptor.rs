#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum FieldValueType {
    Bool,
    CommandList,
    Direction,
    Float,
    Int,
    Object(&'static str),
    RulesMap,
    String,
    Vec3,
}

#[derive(Debug, Clone, Copy, PartialEq)]
pub struct FieldRange {
    pub min: Option<f64>,
    pub max: Option<f64>,
}

impl FieldRange {
    pub const fn at_least(min: f64) -> Self {
        FieldRange {
            min: Some(min),
            max: None,
        }
    }

    pub const fn between(min: f64, max: f64) -> Self {
        FieldRange {
            min: Some(min),
            max: Some(max),
        }
    }
}

#[derive(Debug, Clone, Copy, PartialEq)]
pub struct ObjectFieldDescriptor {
    pub name: &'static str,
    pub value_type: FieldValueType,
    pub range: Option<FieldRange>,
    pub description: &'static str,
}
