//! Clipboard model: stores serialized object data for copy/cut/paste.
//!
//! Ports `scen_edit/view/clipboard.lua`. Objects are stored as JSON values
//! (the same `object_to_json` shape `AddObjectCommand` deserializes), keyed by
//! kind. Paste adjusts positions relative to the cursor's ground hit.

use std::any::Any;

use serde::{Deserialize, Serialize};

use spring_native::prelude::NativeInterfaceRef;

use crate::sbc::command_system::command::Command;
use crate::sbc::command_system::model::{Model, ModelFactory};
use crate::sbc::objects::{AddObjectCommand, ObjectKind};

inventory::submit! {
    ModelFactory { make: |_iface| Box::new(Clipboard::default()) }
}

const SYSTEM_CLIPBOARD_FORMAT: &str = "sbc-editor-objects";
const SYSTEM_CLIPBOARD_VERSION: u32 = 1;

/// The portable object payload stored in the operating system clipboard.
///
/// Keep this separate from `Clipboard`'s in-memory cache: it gives pasted JSON
/// an explicit format marker and leaves room to evolve the payload without
/// mistaking arbitrary clipboard JSON for editor objects.
#[derive(Deserialize, Serialize)]
struct SystemClipboard {
    format: String,
    version: u32,
    objects: Vec<ClipboardObject>,
}

#[derive(Deserialize, Serialize)]
struct ClipboardObject {
    kind: ObjectKind,
    object: serde_json::Value,
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

    /// Publish the copied objects as portable JSON, so another SBC instance
    /// (or a user saving the clipboard contents) can paste them later.
    pub fn write_to_system(&self, interface: &NativeInterfaceRef) {
        let Some(json) = self.system_json() else {
            return;
        };
        if let Err(error) = interface.unsynced_ctrl().set_clipboard(&json) {
            log::warn!("objects: could not write object clipboard: {error:?}");
        }
    }

    fn system_json(&self) -> Option<String> {
        let payload = SystemClipboard {
            format: SYSTEM_CLIPBOARD_FORMAT.to_string(),
            version: SYSTEM_CLIPBOARD_VERSION,
            objects: self
                .copied
                .iter()
                .map(|(kind, object)| ClipboardObject {
                    kind: *kind,
                    object: object.clone(),
                })
                .collect(),
        };
        serde_json::to_string(&payload)
            .map_err(|error| log::warn!("objects: could not serialize object clipboard: {error}"))
            .ok()
    }

    /// Refresh the in-memory cache from the operating system clipboard.
    ///
    /// A non-object clipboard intentionally does *not* fall back to an old
    /// cache: Ctrl+V should follow what the user currently has copied. We only
    /// retain the cache if the platform cannot provide clipboard text at all.
    fn refresh_from_system(&mut self, interface: &NativeInterfaceRef) -> bool {
        let text = match interface.unsynced_read().get_clipboard() {
            Ok(Some(text)) => text,
            Ok(None) => return true,
            Err(error) => {
                log::warn!("objects: could not read object clipboard: {error:?}");
                return true;
            }
        };
        let Ok(payload) = serde_json::from_str::<SystemClipboard>(&text) else {
            return false;
        };
        if payload.format != SYSTEM_CLIPBOARD_FORMAT || payload.version != SYSTEM_CLIPBOARD_VERSION
        {
            return false;
        }
        self.copied = payload
            .objects
            .into_iter()
            .map(|object| (object.kind, object.object))
            .collect();
        true
    }

    /// Build `AddObjectCommand`s for every copied object, offset so the
    /// centroid lands at `(ground_x, ground_z)`. Each object's Y maintains its
    /// original height-above-ground, queried live from the terrain.
    pub fn paste_commands(
        &mut self,
        interface: &NativeInterfaceRef,
        ground_x: f32,
        ground_z: f32,
    ) -> Vec<Box<dyn Command>> {
        if !self.refresh_from_system(interface) {
            return vec![];
        }
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

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn system_json_round_trip_keeps_kinds_and_strips_model_ids() {
        let mut clipboard = Clipboard::default();
        clipboard.copy(&[
            (
                ObjectKind::Unit,
                serde_json::json!({"__modelID": 6, "defName": "armcom", "pos": {"x": 0, "y": 1, "z": 2}}),
            ),
            (
                ObjectKind::Feature,
                serde_json::json!({"__modelID": 7, "defName": "tree", "pos": {"x": 1, "y": 2, "z": 3}}),
            ),
            (
                ObjectKind::Area,
                serde_json::json!({"__modelID": 8, "pos": {"x": 4, "y": 0, "z": 5}, "size": {"x": 6, "y": 0, "z": 7}}),
            ),
        ]);

        let json = clipboard.system_json().expect("clipboard JSON");
        let payload: SystemClipboard = serde_json::from_str(&json).expect("valid clipboard JSON");

        assert_eq!(payload.format, SYSTEM_CLIPBOARD_FORMAT);
        assert_eq!(payload.version, SYSTEM_CLIPBOARD_VERSION);
        assert_eq!(payload.objects.len(), 3);
        assert_eq!(payload.objects[0].kind, ObjectKind::Unit);
        assert_eq!(payload.objects[1].kind, ObjectKind::Feature);
        assert_eq!(payload.objects[2].kind, ObjectKind::Area);
        assert!(payload
            .objects
            .iter()
            .all(|object| object.object.get("__modelID").is_none()));
    }
}

fn pos_xz(json: &serde_json::Value) -> Option<(f32, f32)> {
    let pos = json.get("pos")?;
    Some((
        pos["x"].as_f64().unwrap_or(0.0) as f32,
        pos["z"].as_f64().unwrap_or(0.0) as f32,
    ))
}
