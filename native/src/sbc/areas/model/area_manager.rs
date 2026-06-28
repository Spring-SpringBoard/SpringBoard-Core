use std::any::Any;
use std::collections::HashMap;

use spring_native::prelude::NativeInterfaceRef;

use crate::sbc::command_system::model::{Model, ModelFactory};
use crate::sbc::lua_bridge;

inventory::submit! { ModelFactory { make: |iface| Box::new(AreaManager::new(iface)) } }

/// Map regions used by triggers and editor tools. Pure project state — a map of
/// id → area data plus an id allocator. Mirrors
/// `scen_edit/model/area_manager.lua`; notifies the widget on change.
///
/// An area is a rect `[x1, z1, x2, z2]`, stored as a JSON value.
pub struct AreaManager {
    interface: NativeInterfaceRef,
    areas: HashMap<i32, serde_json::Value>,
    area_id_count: i32,
}

impl Model for AreaManager {
    fn as_any_mut(&mut self) -> &mut dyn Any {
        self
    }
}

impl AreaManager {
    pub fn new(interface: NativeInterfaceRef) -> Self {
        AreaManager {
            interface,
            areas: HashMap::new(),
            area_id_count: 0,
        }
    }

    pub fn add_area(&mut self, area: serde_json::Value, area_id: Option<i32>) -> i32 {
        let id = area_id.unwrap_or(self.area_id_count + 1);
        self.area_id_count = id;
        self.areas.insert(id, area);
        self.notify("onAreaAdded", id, None);
        id
    }

    pub fn set_area(&mut self, area_id: i32, area: serde_json::Value) {
        self.areas.insert(area_id, area.clone());
        self.notify("onAreaChange", area_id, Some(area));
    }

    pub fn get_area(&self, area_id: i32) -> Option<&serde_json::Value> {
        self.areas.get(&area_id)
    }

    fn notify(&self, event: &str, id: i32, area: Option<serde_json::Value>) {
        let mut args = vec![serde_json::json!(id)];
        if let Some(area) = area {
            args.push(area);
        }
        lua_bridge::notify_model(&self.interface, "areaManager", event, args);
    }
}
