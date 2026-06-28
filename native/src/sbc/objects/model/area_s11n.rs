use std::collections::HashMap;

use serde_json::Value;
use spring_native::prelude::NativeInterfaceRef;

use super::object_data::Vec3;
use crate::sbc::lua_bridge;

/// Areas are axis-aligned map rects, not engine objects, so they live entirely
/// here: an id → rect map with its own id allocator (the areaID is the stable id,
/// there is no engine springID). Editor commands carry `{pos, size}`; the rect is
/// `[x1, z1, x2, z2]`.
pub struct AreaS11n {
    interface: NativeInterfaceRef,
    areas: HashMap<i32, [f32; 4]>,
    id_count: i32,
}

impl AreaS11n {
    pub fn new(interface: NativeInterfaceRef) -> Self {
        AreaS11n {
            interface,
            areas: HashMap::new(),
            id_count: 0,
        }
    }

    pub fn latest_model_id(&self) -> i32 {
        self.id_count
    }

    /// Create an area from `{pos, size}`. `model_id` is `Some` on redo/undo-restore
    /// so it keeps its id.
    pub fn add(&mut self, params: &Value, model_id: Option<i32>) -> Option<i32> {
        let rect = rect_from_pos_size(params)?;
        let id = model_id.unwrap_or(self.id_count + 1);
        if id > self.id_count {
            self.id_count = id;
        }
        self.areas.insert(id, rect);
        // The widget has no engine object to read back, so it gets the full data.
        notify(
            &self.interface,
            "WidgetAddObjectCommand",
            id,
            Some(area_value(rect)),
        );
        Some(id)
    }

    /// Remove an area, returning its `{pos, size}` so undo can re-add it.
    pub fn remove(&mut self, model_id: i32) -> Option<Value> {
        let rect = self.areas.remove(&model_id)?;
        notify(&self.interface, "WidgetRemoveObjectCommand", model_id, None);
        Some(area_value(rect))
    }

    pub fn get(&self, model_id: i32) -> Option<Value> {
        self.areas.get(&model_id).map(|rect| area_value(*rect))
    }

    /// Apply the present `pos` / `size` fields, keeping the rect's other axis.
    pub fn set_fields(&mut self, model_id: i32, fields: &Value) {
        let Some(mut rect) = self.areas.get(&model_id).copied() else {
            return;
        };
        if let Some(pos) = fields.get("pos").and_then(as_vec3) {
            rect = rect_with_center(rect, pos.x, pos.z);
            notify_update(&self.interface, model_id, "pos", &fields["pos"]);
        }
        if let Some(size) = fields.get("size").and_then(as_vec3) {
            rect = rect_with_size(rect, size.x, size.z);
            notify_update(&self.interface, model_id, "size", &fields["size"]);
        }
        self.areas.insert(model_id, rect);
    }
}

fn rect_from_pos_size(params: &Value) -> Option<[f32; 4]> {
    let pos = as_vec3(params.get("pos")?)?;
    let size = as_vec3(params.get("size")?)?;
    Some(rect_around(pos.x, pos.z, size.x, size.z))
}

fn rect_with_center(rect: [f32; 4], cx: f32, cz: f32) -> [f32; 4] {
    let (w, h) = (rect[2] - rect[0], rect[3] - rect[1]);
    rect_around(cx, cz, w.abs(), h.abs())
}

fn rect_with_size(rect: [f32; 4], w: f32, h: f32) -> [f32; 4] {
    let cx = (rect[0] + rect[2]) / 2.0;
    let cz = (rect[1] + rect[3]) / 2.0;
    rect_around(cx, cz, w, h)
}

fn rect_around(cx: f32, cz: f32, w: f32, h: f32) -> [f32; 4] {
    [cx - w / 2.0, cz - h / 2.0, cx + w / 2.0, cz + h / 2.0]
}

/// `{pos, size}` for a rect; `y` is unused for a 2D area.
fn area_value(rect: [f32; 4]) -> Value {
    let cx = (rect[0] + rect[2]) / 2.0;
    let cz = (rect[1] + rect[3]) / 2.0;
    serde_json::json!({
        "pos": { "x": cx, "y": 0.0, "z": cz },
        "size": { "x": (rect[2] - rect[0]).abs(), "y": 0.0, "z": (rect[3] - rect[1]).abs() },
    })
}

fn as_vec3(value: &Value) -> Option<Vec3> {
    serde_json::from_value(value.clone()).ok()
}

fn notify(interface: &NativeInterfaceRef, class_name: &str, object_id: i32, object: Option<Value>) {
    let mut data = serde_json::json!({
        "className": class_name,
        "objType": "area",
        "objectID": object_id,
    });
    if let Some(object) = object {
        data["object"] = object;
    }
    lua_bridge::send(
        interface,
        serde_json::json!({ "tag": "command", "data": data }),
    );
}

fn notify_update(interface: &NativeInterfaceRef, object_id: i32, name: &str, value: &Value) {
    lua_bridge::send(
        interface,
        serde_json::json!({
            "tag": "command",
            "data": {
                "className": "WidgetUpdateObjectCommand",
                "objType": "area",
                "objectID": object_id,
                "name": name,
                "value": value,
            }
        }),
    );
}
