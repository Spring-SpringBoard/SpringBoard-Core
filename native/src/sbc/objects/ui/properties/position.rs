use super::model::{component_name, number_f, Position, PropertiesModel, SelectedObject};
use crate::sbc::objects::ObjectKind;

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

    pub(super) fn json(self) -> serde_json::Value {
        serde_json::json!({ "x": self.x, "y": self.y, "z": self.z })
    }

    pub(super) fn from_fields(model: &PropertiesModel, field: &str) -> Self {
        Self {
            x: model.number(&component_name(field, "x")),
            y: model.number(&component_name(field, "y")),
            z: model.number(&component_name(field, "z")),
        }
    }

    pub(super) fn plus(self, delta: Self) -> Self {
        Self {
            x: self.x + delta.x,
            y: self.y + delta.y,
            z: self.z + delta.z,
        }
    }

    pub(super) fn minus(self, other: Self) -> Self {
        Self {
            x: self.x - other.x,
            y: self.y - other.y,
            z: self.z - other.z,
        }
    }
}
