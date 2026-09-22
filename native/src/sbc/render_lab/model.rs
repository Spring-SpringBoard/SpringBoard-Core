//! Panel fields, built at runtime from the renderer's capabilities.

use crate::sbc::panels::field::{Field, FieldValue};
use crate::sbc::panels::fields::{BooleanField, ButtonField, ChoiceField, NumericField};
use crate::sbc::panels::runtime::{EditorModel, FieldMut, FieldRef};

use super::catalogue::{Capabilities, ControlSpec, State};

pub(crate) const NONE: &str = "None";
pub(crate) const VIEW_FIELD: &str = "debugView";
pub(crate) const SOLO_FIELD: &str = "solo";
pub(crate) const EXPLAIN_FIELD: &str = "explain";
pub(crate) const SCENE_FIELD: &str = "scene";
pub(crate) const LOAD_SCENE_FIELD: &str = "loadScene";
pub(crate) const RESET_FIELD: &str = "reset";

/// The renderer item a field maps to.
#[derive(Debug, Clone, PartialEq)]
pub(crate) enum Role {
    Control(String),
    Overlay(String),
    View,
    Solo,
    Explain,
    Scene,
    LoadScene,
    Reset,
}

pub(crate) struct Entry {
    pub role: Role,
    pub field: Box<dyn Field>,
}

#[derive(Default)]
pub(crate) struct LabModel {
    pub entries: Vec<Entry>,
    pub capabilities: Option<Capabilities>,
    pub state: State,
    /// Reply revisions the fields were built from.
    pub built_from: u64,
    pub state_from: u64,
    /// Control whose description is shown.
    pub explaining: Option<String>,
}

pub(crate) fn field_name(id: &str) -> String {
    format!("ctl_{}", id.replace('.', "_"))
}

fn overlay_name(id: &str) -> String {
    format!("ovl_{id}")
}

fn control_field(control: &ControlSpec) -> Box<dyn Field> {
    let name = field_name(&control.id);
    if control.is_switch() {
        let on = control.value.as_bool().unwrap_or(true);
        return Box::new(BooleanField::new(&name, &control.name, on).with_tooltip(&control.what));
    }
    let value = control.value.as_f64().unwrap_or(0.0) as f32;
    let span = (control.max - control.min).max(1e-3);
    let decimals = if span <= 1.0 { 3 } else { 2 };
    Box::new(
        NumericField::new(name, control.name.clone(), value)
            .min(control.min)
            .max(control.max)
            .step(span / 200.0)
            .decimals(decimals)
            .with_tooltip(&control.what),
    )
}

impl LabModel {
    /// Build fields from the capabilities.
    pub fn build(&mut self, capabilities: &Capabilities, revision: u64) {
        let mut entries = Vec::new();
        entries.push(Entry {
            role: Role::Reset,
            field: Box::new(
                ButtonField::new(RESET_FIELD, "Reset")
                    .with_tooltip("Every control back to what the renderer started with."),
            ),
        });
        let mut solo_items = vec![NONE.to_string()];
        solo_items.extend(
            capabilities
                .controls
                .iter()
                .filter(|control| control.solo)
                .map(|control| control.name.clone()),
        );
        entries.push(Entry {
            role: Role::Solo,
            field: Box::new(
                ChoiceField::new(SOLO_FIELD, "Solo", solo_items)
                    .with_tooltip("Show one feature on its own: whatever would drown it out goes off, and comes back when the solo ends."),
            ),
        });
        let views = capabilities
            .views
            .iter()
            .map(|view| view.name.clone())
            .collect();
        entries.push(Entry {
            role: Role::View,
            field: Box::new(
                ChoiceField::new(VIEW_FIELD, "Debug view", views)
                    .with_tooltip("One quantity shown as colour instead of the finished picture."),
            ),
        });
        let mut scenes = vec![NONE.to_string()];
        scenes.extend(capabilities.scenes.iter().map(|scene| scene.name.clone()));
        entries.push(Entry {
            role: Role::Scene,
            field: Box::new(ChoiceField::new(SCENE_FIELD, "Test scene", scenes)),
        });
        entries.push(Entry {
            role: Role::LoadScene,
            field: Box::new(ButtonField::new(LOAD_SCENE_FIELD, "Load").with_tooltip(
                "Replace what is placed with the scene, apply its settings and frame it.",
            )),
        });
        for control in &capabilities.controls {
            entries.push(Entry {
                role: Role::Control(control.id.clone()),
                field: control_field(control),
            });
        }
        for overlay in &capabilities.overlays {
            entries.push(Entry {
                role: Role::Overlay(overlay.id.clone()),
                field: Box::new(
                    BooleanField::new(&overlay_name(&overlay.id), &overlay.name, false)
                        .with_tooltip(&overlay.what),
                ),
            });
        }
        let mut explain = vec![NONE.to_string()];
        explain.extend(capabilities.controls.iter().map(|c| c.name.clone()));
        entries.push(Entry {
            role: Role::Explain,
            field: Box::new(ChoiceField::new(EXPLAIN_FIELD, "Explain", explain)),
        });
        self.entries = entries;
        self.capabilities = Some(capabilities.clone());
        self.built_from = revision;
    }

    /// Copy renderer values into the fields.
    pub fn take_state(&mut self, state: &State, revision: u64) {
        self.state = state.clone();
        self.state_from = revision;
        let Some(capabilities) = &self.capabilities else {
            return;
        };
        let name_of = |id: &str, list: &[super::catalogue::Named]| {
            list.iter()
                .find(|named| named.id == id)
                .map(|named| named.name.clone())
        };
        let solo = state
            .solo
            .as_deref()
            .and_then(|id| capabilities.controls.iter().find(|c| c.id == id))
            .map(|control| control.name.clone())
            .unwrap_or_else(|| NONE.to_string());
        let view = name_of(&state.view, &capabilities.views).unwrap_or_default();
        for entry in &mut self.entries {
            match &entry.role {
                Role::Control(id) => {
                    if let Some(value) = state.values.get(id) {
                        let value = match value {
                            serde_json::Value::Bool(on) => FieldValue::Bool(*on),
                            serde_json::Value::Number(n) => {
                                FieldValue::Number(n.as_f64().unwrap_or(0.0) as f32)
                            }
                            _ => continue,
                        };
                        entry.field.set_value(&value);
                    }
                }
                Role::Overlay(id) => {
                    entry
                        .field
                        .set_value(&FieldValue::Bool(state.overlays.contains(id)));
                }
                Role::Solo => entry.field.set_value(&FieldValue::Text(solo.clone())),
                Role::View => entry.field.set_value(&FieldValue::Text(view.clone())),
                _ => {}
            }
        }
    }

    pub fn role(&self, id: usize) -> Option<&Role> {
        self.entries.get(id).map(|entry| &entry.role)
    }

    pub fn value(&self, id: usize) -> FieldValue {
        self.entries
            .get(id)
            .map(|entry| entry.field.value())
            .unwrap_or(FieldValue::Text(String::new()))
    }

    pub fn id_of_role(&self, role: &Role) -> Option<usize> {
        self.entries.iter().position(|entry| &entry.role == role)
    }

    pub fn control(&self, name_or_id: &str) -> Option<&ControlSpec> {
        self.capabilities
            .as_ref()?
            .controls
            .iter()
            .find(|control| control.name == name_or_id || control.id == name_or_id)
    }
}

impl EditorModel for LabModel {
    type Id = usize;

    fn fields(&self) -> Vec<FieldRef<'_>> {
        self.entries
            .iter()
            .map(|entry| FieldRef {
                field: entry.field.as_ref(),
                brush: None,
            })
            .collect()
    }

    fn fields_mut(&mut self) -> Vec<FieldMut<'_>> {
        self.entries
            .iter_mut()
            .map(|entry| FieldMut {
                field: entry.field.as_mut(),
                brush: None,
            })
            .collect()
    }

    fn id_of(&self, name: &str) -> Option<usize> {
        self.entries
            .iter()
            .position(|entry| entry.field.name() == name)
    }

    fn name_of(&self, id: usize) -> String {
        self.entries
            .get(id)
            .map(|entry| entry.field.name().to_string())
            .unwrap_or_default()
    }
}
