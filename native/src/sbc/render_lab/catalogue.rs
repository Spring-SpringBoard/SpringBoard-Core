//! Deserialized renderer capabilities: controls, views, overlays, scenes. Ids are rendering
//! concepts, not shader uniforms.

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
}

#[derive(Debug, Clone, Deserialize, PartialEq)]
pub(crate) struct Named {
    pub id: String,
    pub name: String,
    #[serde(default)]
    pub what: String,
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
}
