//! Panel fields, built at runtime from the renderer's capabilities.

use spring_native::prelude::Error;
use spring_native::{RmlDataModel, RmlDataVariable};

use crate::sbc::panels::field::{Field, FieldValue};
use crate::sbc::panels::fields::{BooleanField, ButtonField, ChoiceField, NumericField};
use crate::sbc::panels::runtime::{EditorModel, FieldMut, FieldRef};

use super::catalogue::{Capabilities, ControlSpec, State, RENDER_PANEL};

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

pub(crate) struct LabModel {
    /// The panel these fields are for: it shows only the categories and scenes naming it.
    pub panel: &'static str,
    pub entries: Vec<Entry>,
    pub capabilities: Option<Capabilities>,
    pub state: State,
    /// Reply revisions the fields were built from.
    pub built_from: u64,
    pub state_from: u64,
    /// Control whose description is shown.
    pub explaining: Option<String>,
    /// Text the panel shows that changes with the renderer's state, bound so it updates in
    /// place: rebuilding the markup for it would make the whole panel flicker.
    display: Display,
}

#[derive(Default)]
struct Display {
    status: Option<RmlDataVariable<'static, String>>,
    scene_note: Option<RmlDataVariable<'static, String>>,
    scene_note_shown: Option<RmlDataVariable<'static, bool>>,
}

/// Data-model names of the bound status line and scene description.
pub(crate) const STATUS_BINDING: &str = "render_lab_status";
pub(crate) const SCENE_NOTE_BINDING: &str = "render_lab_scene_note";
pub(crate) const SCENE_NOTE_SHOWN_BINDING: &str = "render_lab_scene_note_shown";

impl Default for LabModel {
    fn default() -> Self {
        Self::for_panel(RENDER_PANEL)
    }
}

pub(crate) fn field_name(id: &str) -> String {
    format!("ctl_{}", id.replace('.', "_"))
}

fn overlay_name(id: &str) -> String {
    format!("ovl_{id}")
}

fn control_field(control: &ControlSpec) -> Box<dyn Field> {
    let name = field_name(&control.id);
    if control.is_button() {
        return Box::new(ButtonField::new(&name, &control.name).with_tooltip(&control.what));
    }
    if control.is_switch() {
        let on = control.value.as_bool().unwrap_or(true);
        return Box::new(BooleanField::new(&name, &control.name, on).with_tooltip(&control.what));
    }
    if control.kind == "choice" {
        let mut field = ChoiceField::new(name, control.name.clone(), control.choices.clone())
            .with_tooltip(&control.what);
        if let Some(chosen) = control
            .choices
            .get(control.value.as_u64().unwrap_or(0) as usize)
        {
            field.set_value(&FieldValue::Text(chosen.clone()));
        }
        return Box::new(field);
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
    pub fn for_panel(panel: &'static str) -> Self {
        Self {
            panel,
            entries: Vec::new(),
            capabilities: None,
            state: State::default(),
            built_from: 0,
            state_from: 0,
            explaining: None,
            display: Display::default(),
        }
    }

    /// The Rendering Lab: the panel for categories and scenes that name none, and the one
    /// with the debug views and overlays.
    pub fn is_render_panel(&self) -> bool {
        self.panel == RENDER_PANEL
    }

    /// What Reset covers: this panel, once the renderer names panels at all. A renderer that
    /// names none has one panel, and is sent the plain `reset` it knows.
    pub fn reset_scope(&self) -> Option<&'static str> {
        let capabilities = self.capabilities.as_ref()?;
        let names_panels = capabilities
            .all_categories()
            .iter()
            .chain(&capabilities.scenes)
            .any(|named| !named.panels.is_empty());
        names_panels.then_some(self.panel)
    }

    /// Build fields from the capabilities, only for what this panel shows.
    pub fn build(&mut self, capabilities: &Capabilities, revision: u64) {
        let controls = capabilities.controls_in(self.panel);
        let mut entries = Vec::new();
        entries.push(Entry {
            role: Role::Reset,
            field: Box::new(
                ButtonField::new(RESET_FIELD, "Reset")
                    .with_tooltip("This panel's controls back to what the renderer started with."),
            ),
        });
        let mut solo_items = vec![NONE.to_string()];
        solo_items.extend(
            controls
                .iter()
                .filter(|control| control.solo)
                .map(|control| control.name.clone()),
        );
        if solo_items.len() > 1 {
            entries.push(Entry {
                role: Role::Solo,
                field: Box::new(
                    ChoiceField::new(SOLO_FIELD, "Solo", solo_items)
                        .with_tooltip("Show one feature on its own: whatever would drown it out goes off, and comes back when the solo ends."),
                ),
            });
        }
        if self.is_render_panel() {
            let views = capabilities
                .views
                .iter()
                .map(|view| view.name.clone())
                .collect();
            entries.push(Entry {
                role: Role::View,
                field: Box::new(
                    ChoiceField::new(VIEW_FIELD, "Debug view", views).with_tooltip(
                        "One quantity shown as colour instead of the finished picture.",
                    ),
                ),
            });
        }
        let mut scenes = vec![NONE.to_string()];
        scenes.extend(
            capabilities
                .scenes_in(self.panel)
                .into_iter()
                .map(|scene| scene.name.clone()),
        );
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
        for control in &controls {
            entries.push(Entry {
                role: Role::Control(control.id.clone()),
                field: control_field(control),
            });
        }
        let overlays = if self.is_render_panel() {
            capabilities.overlays.as_slice()
        } else {
            &[]
        };
        for overlay in overlays {
            entries.push(Entry {
                role: Role::Overlay(overlay.id.clone()),
                field: Box::new(
                    BooleanField::new(&overlay_name(&overlay.id), &overlay.name, false)
                        .with_tooltip(&overlay.what),
                ),
            });
        }
        let shown = capabilities.categories_in(self.panel);
        let mut explain = vec![NONE.to_string()];
        explain.extend(
            controls
                .iter()
                .filter(|c| shown.iter().any(|s| s.id == c.category && !s.hidden))
                .map(|c| c.name.clone()),
        );
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
        // The scene list shows the loaded scene only when that changes: a reply about something
        // else must not undo a scene chosen and not yet loaded.
        let scene_changed = self.state_from == 0 || self.state.scene != state.scene;
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
                // The user's hand is on it: the reply describes a value already passed.
                _ if entry.field.interacting() => {}
                Role::Control(id) => {
                    // A button keeps nothing to show; setting it would press it.
                    if capabilities
                        .controls
                        .iter()
                        .any(|c| c.id == *id && c.is_button())
                    {
                        continue;
                    }
                    if let Some(value) = state.values.get(id) {
                        let choice = capabilities
                            .controls
                            .iter()
                            .find(|c| c.id == *id && c.kind == "choice");
                        let value = if let Some(choice) = choice {
                            let Some(name) =
                                choice.choices.get(value.as_f64().unwrap_or(0.0) as usize)
                            else {
                                continue;
                            };
                            FieldValue::Text(name.clone())
                        } else {
                            match value {
                                serde_json::Value::Bool(on) => FieldValue::Bool(*on),
                                serde_json::Value::Number(n) => {
                                    FieldValue::Number(n.as_f64().unwrap_or(0.0) as f32)
                                }
                                _ => continue,
                            }
                        };
                        entry.field.set_value(&value);
                    }
                }
                Role::Overlay(id) => {
                    entry
                        .field
                        .set_value(&FieldValue::Bool(state.overlays.contains(id)));
                }
                Role::Scene if !scene_changed => {}
                Role::Scene => {
                    // A scene another panel loaded reads as none here.
                    let name = state
                        .scene
                        .as_deref()
                        .and_then(|id| {
                            capabilities
                                .scenes_in(self.panel)
                                .into_iter()
                                .find(|named| named.id == id)
                        })
                        .map(|named| named.name.clone())
                        .unwrap_or_else(|| NONE.to_string());
                    entry.field.set_value(&FieldValue::Text(name));
                }
                Role::Solo => entry.field.set_value(&FieldValue::Text(solo.clone())),
                Role::View => entry.field.set_value(&FieldValue::Text(view.clone())),
                _ => {}
            }
        }
    }

    /// The renderer's status line: light counts, solo, scene.
    pub fn status(&self) -> String {
        let state = &self.state;
        let mut parts = vec![format!(
            "{} lights, {} used",
            state.lights.candidates, state.lights.chosen
        )];
        if let Some(solo) = &state.solo {
            parts.push(format!("solo {solo}"));
        }
        if let Some(scene) = &state.scene {
            parts.push(format!("scene {scene}"));
        }
        parts.join(", ")
    }

    /// What the scene chosen in the list shows, if it says.
    pub fn scene_note(&self) -> Option<String> {
        let scene = self.id_of_role(&Role::Scene)?;
        let FieldValue::Text(name) = self.value(scene) else {
            return None;
        };
        self.capabilities
            .as_ref()?
            .scenes_in(self.panel)
            .into_iter()
            .find(|scene| scene.name == name)
            .map(|scene| scene.what.clone())
            .filter(|what| !what.is_empty())
    }

    /// Put the status line and the scene's description into the panel as it stands.
    pub fn show_display(&self) {
        if let Some(status) = &self.display.status {
            let _ = status.set(self.status());
        }
        let note = self.scene_note();
        if let Some(shown) = &self.display.scene_note_shown {
            let _ = shown.set(note.is_some());
        }
        if let Some(text) = &self.display.scene_note {
            let _ = text.set(note.unwrap_or_default());
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

    fn prepare_data_model(&mut self, model: &RmlDataModel<'static>) -> Result<(), Error> {
        self.display = Display {
            status: Some(model.bind(STATUS_BINDING, self.status())?),
            scene_note: Some(
                model.bind(SCENE_NOTE_BINDING, self.scene_note().unwrap_or_default())?,
            ),
            scene_note_shown: Some(
                model.bind(SCENE_NOTE_SHOWN_BINDING, self.scene_note().is_some())?,
            ),
        };
        Ok(())
    }

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

#[cfg(test)]
mod tests {
    use super::*;
    use crate::sbc::panels::runtime::Item;

    #[test]
    fn renderer_choices_build_a_dropdown_and_take_numeric_state() {
        let capabilities: Capabilities = serde_json::from_value(serde_json::json!({
            "controls": [{"id":"frame.space_map", "name":"Space map", "category":"frame",
                "kind":"choice", "choices":["Classic", "Amber Veil", "Silver Rift"], "value":2}],
            "scenes": [{"id":"inspect_phalanx", "name":"Ship: phalanx"}]
        }))
        .unwrap();
        let mut model = LabModel::default();
        model.build(&capabilities, 1);
        let id = model.id_of("ctl_frame_space_map").unwrap();
        assert_eq!(model.value(id), FieldValue::Text("Silver Rift".into()));
        let state: State = serde_json::from_value(
            serde_json::json!({"values":{"frame.space_map":1}, "scene":"inspect_phalanx"}),
        )
        .unwrap();
        model.take_state(&state, 2);
        assert_eq!(model.value(id), FieldValue::Text("Amber Veil".into()));
        assert_eq!(
            model.value(model.id_of(SCENE_FIELD).unwrap()),
            FieldValue::Text("Ship: phalanx".into())
        );
    }

    /// A numeric field the user is dragging: what the game sends meanwhile is already old.
    struct Dragged(Box<dyn Field>);

    impl Field for Dragged {
        fn name(&self) -> &str {
            self.0.name()
        }
        fn generate_rml(&self) -> String {
            self.0.generate_rml()
        }
        fn bind(
            &mut self,
            interface: &spring_native::prelude::NativeInterfaceRef,
            document: u64,
            changes: &crate::sbc::panels::field::ChangeQueue,
            interactions: &crate::sbc::panels::field::InteractionQueue,
        ) -> Result<(), Error> {
            self.0.bind(interface, document, changes, interactions)
        }
        fn read_from_dom(
            &mut self,
            interface: &spring_native::prelude::NativeInterfaceRef,
        ) -> Result<FieldValue, Error> {
            self.0.read_from_dom(interface)
        }
        fn write_to_dom(
            &self,
            interface: &spring_native::prelude::NativeInterfaceRef,
        ) -> Result<(), Error> {
            self.0.write_to_dom(interface)
        }
        fn set_value(&mut self, value: &FieldValue) {
            self.0.set_value(value)
        }
        fn value(&self) -> FieldValue {
            self.0.value()
        }
        fn interacting(&self) -> bool {
            true
        }
    }

    #[test]
    fn a_field_in_the_users_hand_keeps_its_value_while_others_follow_the_reply() {
        let capabilities: Capabilities = serde_json::from_value(serde_json::json!({
            "controls": [
                {"id":"effects.glow_gain", "name":"Glow gain", "category":"scales",
                    "kind":"number", "value":1, "min":0, "max":4},
                {"id":"effects.jet_gain", "name":"Jet gain", "category":"scales",
                    "kind":"number", "value":1, "min":0, "max":4}
            ]
        }))
        .unwrap();
        let mut model = LabModel::default();
        model.build(&capabilities, 1);
        let glow = model.id_of("ctl_effects_glow_gain").unwrap();
        let jet = model.id_of("ctl_effects_jet_gain").unwrap();
        model.entries[glow]
            .field
            .set_value(&FieldValue::Number(2.5));
        let field = std::mem::replace(
            &mut model.entries[glow].field,
            Box::new(BooleanField::new("placeholder", "", false)),
        );
        model.entries[glow].field = Box::new(Dragged(field));
        let state: State = serde_json::from_value(serde_json::json!(
            {"values":{"effects.glow_gain":2.0, "effects.jet_gain":3.0}}
        ))
        .unwrap();
        model.take_state(&state, 2);
        assert_eq!(model.value(glow), FieldValue::Number(2.5));
        assert_eq!(model.value(jet), FieldValue::Number(3.0));
    }

    #[test]
    fn the_status_line_and_scene_note_are_bound_not_written_into_the_markup() {
        let capabilities: Capabilities = serde_json::from_value(serde_json::json!({
            "controls": [],
            "scenes": [{"id":"inspect_phalanx", "name":"Ship: phalanx", "what":"A Phalanx, close."}]
        }))
        .unwrap();
        let mut model = LabModel::default();
        model.build(&capabilities, 1);
        let state: State = serde_json::from_value(serde_json::json!(
            {"lights":{"candidates":7, "chosen":3}, "scene":"inspect_phalanx"}
        ))
        .unwrap();
        model.take_state(&state, 2);
        let markup: String = super::super::layout::layout(&model)
            .into_iter()
            .filter_map(|item| match item {
                Item::OwnedSection(text) | Item::Custom(text) => Some(text),
                _ => None,
            })
            .collect();
        assert!(!markup.contains("7 lights") && !markup.contains("A Phalanx, close."));
        assert!(markup.contains(STATUS_BINDING) && markup.contains(SCENE_NOTE_BINDING));
        assert_eq!(model.status(), "7 lights, 3 used, scene inspect_phalanx");
        assert_eq!(model.scene_note().as_deref(), Some("A Phalanx, close."));
    }

    #[test]
    fn categories_and_scenes_go_to_the_panels_they_name() {
        let capabilities: Capabilities = serde_json::from_value(serde_json::json!({
            "controls": [
                {"id":"material.dirt", "name":"Dirt", "category":"material", "kind":"switch", "value":true},
                {"id":"effects.drives", "name":"Drives", "category":"effects", "kind":"switch", "value":true},
                {"id":"fire.size", "name":"Size", "category":"fire", "kind":"number",
                    "min":0.25, "max":4.0, "value":1.0},
                {"id":"camera.distance", "name":"Distance", "category":"camera", "kind":"number",
                    "min":1.0, "max":2.0, "value":1.5}
            ],
            "categories": [
                {"id":"material", "name":"Material"},
                {"id":"effects", "name":"Effects", "panels":["tuning"]},
                {"id":"fire", "name":"Fire an effect", "panels":["fire"]},
                {"id":"camera", "name":"Camera", "panels":["render", "stages"]}
            ],
            "views": [{"id":"final", "name":"Final"}],
            "overlays": [{"id":"lights", "name":"Lights"}],
            "scenes": [
                {"id":"material", "name":"Material"},
                {"id":"fx_drives", "name":"Effect: drives", "panels":["stages"]}
            ]
        }))
        .unwrap();
        let built = |panel: &'static str| {
            let mut model = LabModel::for_panel(panel);
            model.build(&capabilities, 1);
            model
        };
        let (mut render, mut stages, tuning, fire) = (
            LabModel::default(),
            built("stages"),
            built("tuning"),
            built("fire"),
        );
        render.build(&capabilities, 1);
        let has = |model: &LabModel, name: &str| model.id_of(name).is_some();
        assert!(has(&render, "ctl_material_dirt") && !has(&render, "ctl_effects_drives"));
        assert!(has(&tuning, "ctl_effects_drives") && !has(&tuning, "ctl_material_dirt"));
        assert!(has(&fire, "ctl_fire_size") && !has(&fire, "ctl_effects_drives"));
        assert!(!has(&stages, "ctl_fire_size") && !has(&stages, "ctl_effects_drives"));
        assert!(has(&render, "ctl_camera_distance") && has(&stages, "ctl_camera_distance"));
        assert!(!has(&tuning, "ctl_camera_distance") && !has(&fire, "ctl_camera_distance"));
        assert!(has(&render, VIEW_FIELD) && has(&render, "ovl_lights"));
        assert!(!has(&stages, VIEW_FIELD) && !has(&tuning, "ovl_lights"));
        let scenes = |model: &LabModel| {
            let field = &model.entries[model.id_of(SCENE_FIELD).unwrap()].field;
            field.value()
        };
        let state: State =
            serde_json::from_value(serde_json::json!({"scene":"fx_drives"})).unwrap();
        render.take_state(&state, 2);
        stages.take_state(&state, 2);
        assert_eq!(scenes(&render), FieldValue::Text(NONE.into()));
        assert_eq!(scenes(&stages), FieldValue::Text("Effect: drives".into()));
        // Each Reset covers its own panel; a renderer naming no panels gets the plain reset.
        assert_eq!(tuning.reset_scope(), Some("tuning"));
        assert_eq!(render.reset_scope(), Some("render"));
        let plain: Capabilities = serde_json::from_value(serde_json::json!({
            "controls": [], "categories": [{"id":"material", "name":"Material"}]
        }))
        .unwrap();
        let mut old = LabModel::default();
        old.build(&plain, 1);
        assert_eq!(old.reset_scope(), None);
    }

    #[test]
    fn buttons_press_without_state_and_hidden_categories_are_not_laid_out() {
        let capabilities: Capabilities = serde_json::from_value(serde_json::json!({
            "controls": [
                {"id":"stage.replay", "name":"Replay", "category":"stage", "kind":"button", "value":false},
                {"id":"stage.frame", "name":"Pause at frame", "category":"capture", "kind":"number",
                    "min":-1.0, "max":10.0, "value":-1.0}
            ],
            "categories": [
                {"id":"stage", "name":"Stage", "panels":["stages"]},
                {"id":"capture", "name":"Capture", "panels":["stages"], "hidden":true}
            ]
        }))
        .unwrap();
        let mut model = LabModel::for_panel("stages");
        model.build(&capabilities, 1);
        let replay = model.id_of("ctl_stage_replay").unwrap();
        assert!(
            model.id_of("ctl_stage_frame").is_some(),
            "scripts reach hidden controls"
        );
        let state: State =
            serde_json::from_value(serde_json::json!({"values":{"stage.replay":false}})).unwrap();
        let before = model.value(replay);
        model.take_state(&state, 2);
        assert_eq!(
            model.value(replay),
            before,
            "a state update presses nothing"
        );
        let layout = super::super::layout::layout(&model);
        let laid: Vec<usize> = layout
            .iter()
            .flat_map(|item| match item {
                Item::Field(id) => vec![*id],
                Item::OwnedRow(ids) => ids.clone(),
                _ => vec![],
            })
            .collect();
        assert!(laid.contains(&replay));
        assert!(!laid.contains(&model.id_of("ctl_stage_frame").unwrap()));
    }

    #[test]
    fn a_reply_about_something_else_keeps_the_scene_chosen() {
        let capabilities: Capabilities = serde_json::from_value(serde_json::json!({
            "controls": [],
            "scenes": [{"id":"a", "name":"A"}, {"id":"b", "name":"B"}]
        }))
        .unwrap();
        let mut model = LabModel::default();
        model.build(&capabilities, 1);
        let scene = model.id_of(SCENE_FIELD).unwrap();
        let on_a: State = serde_json::from_value(serde_json::json!({"scene":"a"})).unwrap();
        model.take_state(&on_a, 2);
        model.entries[scene]
            .field
            .set_value(&FieldValue::Text("B".into()));
        model.take_state(&on_a, 3);
        assert_eq!(model.value(scene), FieldValue::Text("B".into()));
        let on_b: State = serde_json::from_value(serde_json::json!({"scene":"b"})).unwrap();
        model.take_state(&on_b, 4);
        model.take_state(&on_a, 5);
        assert_eq!(model.value(scene), FieldValue::Text("A".into()));
    }
}
