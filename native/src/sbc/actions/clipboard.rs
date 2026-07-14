//! Clipboard model: stores serialized object data for copy/cut/paste.
//!
//! Ports `scen_edit/view/clipboard.lua`. Objects are stored as JSON values
//! (the same `object_to_json` shape `AddObjectCommand` deserializes), keyed by
//! kind. Paste adjusts positions relative to the cursor's ground hit.

use std::any::Any;

use spring_native::prelude::NativeInterfaceRef;

use crate::sbc::command_system::command::Command;
use crate::sbc::command_system::model::{Model, ModelFactory};
use crate::sbc::objects::{AddObjectCommand, ObjectKind};

inventory::submit! {
    ModelFactory { make: |_iface| Box::new(Clipboard::default()) }
}

#[derive(Default)]
pub struct Clipboard {
    /// (kind, object_json) pairs — one per copied object.
    copied: Vec<(ObjectKind, serde_json::Value)>,
}

impl Model for Clipboard {
    fn as_any_mut(&mut self) -> &mut dyn Any {
        self
    }
}

impl Clipboard {
    pub fn is_empty(&self) -> bool {
        self.copied.is_empty()
    }

    pub fn copy(&mut self, items: &[(ObjectKind, serde_json::Value)]) {
        self.copied.clear();
        for (kind, json) in items {
            let mut json = json.clone();
            // Strip the model id so paste creates new objects.
            if let serde_json::Value::Object(map) = &mut json {
                map.remove("__modelID");
            }
            self.copied.push((*kind, json));
        }
    }

    /// Build `AddObjectCommand`s for every copied object, offset so the
    /// centroid lands at `(ground_x, ground_z)`. Each object's Y maintains its
    /// original height-above-ground, queried live from the terrain.
    pub fn paste_commands(
        &self,
        interface: &NativeInterfaceRef,
        ground_x: f32,
        ground_z: f32,
    ) -> Vec<Box<dyn Command>> {
        if self.copied.is_empty() {
            return vec![];
        }

        // Compute centroid of copied objects' positions.
        let mut cx = 0.0_f32;
        let mut cz = 0.0_f32;
        let mut count = 0_usize;
        for (_, json) in &self.copied {
            if let Some((x, z)) = pos_xz(json) {
                cx += x;
                cz += z;
                count += 1;
            }
        }
        if count == 0 {
            return vec![];
        }
        let dx = ground_x - cx / count as f32;
        let dz = ground_z - cz / count as f32;

        let terrain = interface.terrain();
        let mut commands = Vec::new();
        for (kind, json) in &self.copied {
            let mut obj = json.clone();
            if let serde_json::Value::Object(map) = &mut obj {
                if let Some(pos) = map.get_mut("pos").and_then(|p| p.as_object_mut()) {
                    let ox = pos["x"].as_f64().unwrap_or(0.0) as f32;
                    let oy = pos["y"].as_f64().unwrap_or(0.0) as f32;
                    let oz = pos["z"].as_f64().unwrap_or(0.0) as f32;
                    let nx = ox + dx;
                    let nz = oz + dz;
                    // Maintain height-above-ground.
                    let old_gh = terrain.get_ground_height(ox, oz).unwrap_or(0.0);
                    let new_gh = terrain.get_ground_height(nx, nz).unwrap_or(0.0);
                    let ny = new_gh + (oy - old_gh);
                    pos["x"] = serde_json::json!(nx);
                    pos["y"] = serde_json::json!(ny);
                    pos["z"] = serde_json::json!(nz);
                }
            }
            commands.push(Box::new(AddObjectCommand::new(*kind, obj)) as Box<dyn Command>);
        }
        commands
    }
}

fn pos_xz(json: &serde_json::Value) -> Option<(f32, f32)> {
    let pos = json.get("pos")?;
    Some((
        pos["x"].as_f64().unwrap_or(0.0) as f32,
        pos["z"].as_f64().unwrap_or(0.0) as f32,
    ))
}
