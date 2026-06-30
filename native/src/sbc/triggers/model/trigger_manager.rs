use std::any::Any;
use std::collections::HashMap;

use spring_native::prelude::NativeInterfaceRef;

use crate::sbc::command_system::model::{Model, ModelFactory};
use crate::sbc::lua_bridge;

inventory::submit! { ModelFactory { make: |iface| Box::new(TriggerManager::new(iface)) } }

/// Triggers (event/condition/action rules) - id -> arbitrary JSON, plus an id
/// allocator. CRUD half of `trigger_manager.lua`; mirrors into LuaRules because
/// the Lua trigger runtime reads the synced Lua model.
pub struct TriggerManager {
    interface: NativeInterfaceRef,
    triggers: HashMap<i32, serde_json::Value>,
    trigger_id_count: i32,
}

impl Model for TriggerManager {
    fn as_any_mut(&mut self) -> &mut dyn Any {
        self
    }
}

impl TriggerManager {
    pub fn new(interface: NativeInterfaceRef) -> Self {
        TriggerManager {
            interface,
            triggers: HashMap::new(),
            trigger_id_count: 0,
        }
    }

    /// Add a trigger, allocating an id if it has none. Returns the id.
    pub fn add_trigger(&mut self, mut trigger: serde_json::Value) -> i32 {
        let id = trigger
            .get("id")
            .and_then(|v| v.as_i64())
            .map(|v| v as i32)
            .unwrap_or(self.trigger_id_count + 1);
        if let Some(obj) = trigger.as_object_mut() {
            obj.insert("id".to_string(), serde_json::json!(id));
        }
        if id > self.trigger_id_count {
            self.trigger_id_count = id;
        }
        self.triggers.insert(id, trigger);
        self.mirror_add(id);
        id
    }

    pub fn remove_trigger(&mut self, id: i32) -> bool {
        if self.triggers.remove(&id).is_some() {
            self.mirror_remove(id);
            true
        } else {
            false
        }
    }

    pub fn set_trigger(&mut self, id: i32, value: serde_json::Value) {
        self.triggers.insert(id, value);
        self.mirror_update(id);
    }

    pub fn get_trigger(&self, id: i32) -> Option<&serde_json::Value> {
        self.triggers.get(&id)
    }

    /// Whole-model save: trigger values sorted by id (`load` re-keys by each `id`).
    #[allow(dead_code)]
    pub fn serialize(&self) -> serde_json::Value {
        let mut ids: Vec<&i32> = self.triggers.keys().collect();
        ids.sort();
        let list: Vec<serde_json::Value> = ids
            .into_iter()
            .map(|id| self.triggers[id].clone())
            .collect();
        serde_json::Value::Array(list)
    }

    /// Load from `serialize()` output, mirroring `TriggerManager:load`: re-add
    /// each trigger (which keeps its own `id`).
    #[allow(dead_code)]
    pub fn load(&mut self, data: &serde_json::Value) {
        self.triggers.clear();
        self.trigger_id_count = 0;
        if let Some(list) = data.as_array() {
            for trigger in list {
                self.add_trigger(trigger.clone());
            }
        }
    }

    /// Drop all triggers (the Lua `TriggerManager:clear`).
    #[allow(dead_code)]
    pub fn clear(&mut self) {
        let ids: Vec<i32> = self.triggers.keys().copied().collect();
        for id in ids {
            self.remove_trigger(id);
        }
        self.trigger_id_count = 0;
    }

    fn mirror_add(&self, id: i32) {
        if let Some(trigger) = self.triggers.get(&id) {
            lua_bridge::rules_command(
                &self.interface,
                serde_json::json!({
                    "className": "WidgetAddTriggerCommand",
                    "id": id,
                    "value": trigger,
                }),
            );
        }
    }

    fn mirror_remove(&self, id: i32) {
        lua_bridge::rules_command(
            &self.interface,
            serde_json::json!({
                "className": "WidgetRemoveTriggerCommand",
                "id": id,
            }),
        );
    }

    fn mirror_update(&self, id: i32) {
        if let Some(trigger) = self.triggers.get(&id) {
            lua_bridge::rules_command(
                &self.interface,
                serde_json::json!({
                    "className": "WidgetUpdateTriggerCommand",
                    "trigger": trigger,
                }),
            );
        }
    }
}
