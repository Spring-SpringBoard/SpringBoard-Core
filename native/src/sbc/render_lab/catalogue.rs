//! Deserialized renderer capabilities: controls, views, overlays, scenes. Ids are rendering
//! concepts, not shader uniforms.
//!
//! A category or scene may name the panels it is shown in (`panels`); one that names none is
//! shown in the Rendering Lab. A `hidden` category's controls are fields scripts can reach, but
//! the panel does not lay them out.

use std::collections::BTreeMap;

use serde::Deserialize;

#[derive(Debug, Clone, Deserialize, PartialEq)]
pub(crate) struct ControlSpec {
    pub id: String,
    pub name: String,
    pub category: String,
    pub kind: String,
    #[serde(default)]
    pub min: f32,
    #[serde(default)]
    pub max: f32,
    #[serde(default)]
    pub choices: Vec<String>,
    pub value: serde_json::Value,
    #[serde(default)]
    pub what: String,
    #[serde(default)]
    pub how: String,
    #[serde(default)]
    pub look: String,
    #[serde(default)]
    pub solo: bool,
}

impl ControlSpec {
    pub fn is_switch(&self) -> bool {
        self.kind == "switch"
    }

    /// A push button: each press is sent, nothing is shown back.
    pub fn is_button(&self) -> bool {
        self.kind == "button"
    }
}

/// The panel a category or scene goes to when it names none.
pub(crate) const RENDER_PANEL: &str = "render";

#[derive(Debug, Clone, Deserialize, PartialEq)]
pub(crate) struct Named {
    pub id: String,
    pub name: String,
    #[serde(default)]
    pub what: String,
    #[serde(default)]
    pub panels: Vec<String>,
    #[serde(default)]
    pub hidden: bool,
}

impl Named {
    pub fn shown_in(&self, panel: &str) -> bool {
        if self.panels.is_empty() {
            panel == RENDER_PANEL
        } else {
            self.panels.iter().any(|named| named == panel)
        }
    }
}

#[derive(Debug, Clone, Deserialize, PartialEq, Default)]
pub(crate) struct Capabilities {
    pub controls: Vec<ControlSpec>,
    #[serde(default)]
    pub categories: Vec<Named>,
    #[serde(default)]
    pub views: Vec<Named>,
    #[serde(default)]
    pub overlays: Vec<Named>,
    #[serde(default)]
    pub scenes: Vec<Named>,
}

impl Capabilities {
    /// Categories in the renderer's order, plus any used by a control but not listed.
    pub fn all_categories(&self) -> Vec<Named> {
        let mut categories = self.categories.clone();
        for control in &self.controls {
            if !categories.iter().any(|c| c.id == control.category) {
                categories.push(Named {
                    id: control.category.clone(),
                    name: control.category.clone(),
                    what: String::new(),
                    panels: Vec::new(),
                    hidden: false,
                });
            }
        }
        categories
    }

    /// The categories one panel shows, in order.
    pub fn categories_in(&self, panel: &str) -> Vec<Named> {
        self.all_categories()
            .into_iter()
            .filter(|category| category.shown_in(panel))
            .collect()
    }

    /// The controls one panel shows, in the renderer's order.
    pub fn controls_in(&self, panel: &str) -> Vec<&ControlSpec> {
        let categories = self.categories_in(panel);
        self.controls
            .iter()
            .filter(|control| categories.iter().any(|c| c.id == control.category))
            .collect()
    }

    /// Whether any category or scene names the panel.
    pub fn offers(&self, panel: &str) -> bool {
        self.all_categories()
            .iter()
            .chain(&self.scenes)
            .any(|named| named.panels.iter().any(|named| named == panel))
    }

    /// The test scenes one panel offers.
    pub fn scenes_in(&self, panel: &str) -> Vec<&Named> {
        self.scenes
            .iter()
            .filter(|scene| scene.shown_in(panel))
            .collect()
    }
}

#[derive(Debug, Clone, Deserialize, PartialEq, Default)]
pub(crate) struct Lights {
    #[serde(default)]
    pub candidates: u32,
    #[serde(default)]
    pub chosen: u32,
}

/// Current renderer state, sent after every command.
#[derive(Debug, Clone, Deserialize, PartialEq, Default)]
pub(crate) struct State {
    #[serde(default)]
    pub values: BTreeMap<String, serde_json::Value>,
    #[serde(default)]
    pub view: String,
    #[serde(default, rename = "overlays_on")]
    pub overlays: Vec<String>,
    #[serde(default)]
    pub solo: Option<String>,
    #[serde(default)]
    pub scene: Option<String>,
    #[serde(default)]
    pub lights: Lights,
    /// A line the renderer wants read: a mistake in a file it loads, for one.
    #[serde(default)]
    pub note: Option<String>,
}
