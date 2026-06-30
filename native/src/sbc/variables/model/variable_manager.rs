use std::any::Any;
use std::collections::HashMap;

use spring_native::prelude::NativeInterfaceRef;

use crate::sbc::command_system::model::{Model, ModelFactory};
use crate::sbc::lua_bridge;

inventory::submit! { ModelFactory { make: |iface| Box::new(VariableManager::new(iface)) } }

/// Project-scoped variables - id -> arbitrary JSON, plus an id allocator. CRUD
/// mirror of `variable_manager.lua`; mirrors into LuaRules because triggers
/// resolve variables from the synced Lua runtime model.
pub struct VariableManager {
    interface: NativeInterfaceRef,
    variables: HashMap<i32, serde_json::Value>,
    variable_id_count: i32,
}

impl Model for VariableManager {
    fn as_any_mut(&mut self) -> &mut dyn Any {
        self
    }
}

impl VariableManager {
    pub fn new(interface: NativeInterfaceRef) -> Self {
        VariableManager {
            interface,
            variables: HashMap::new(),
            variable_id_count: 0,
        }
    }

    /// Add a variable, allocating an id if it has none. Returns the id.
    pub fn add_variable(&mut self, mut variable: serde_json::Value) -> i32 {
        let id = variable
            .get("id")
            .and_then(|v| v.as_i64())
            .map(|v| v as i32)
            .unwrap_or(self.variable_id_count + 1);
        if let Some(obj) = variable.as_object_mut() {
            obj.insert("id".to_string(), serde_json::json!(id));
        }
        if id > self.variable_id_count {
            self.variable_id_count = id;
        }
        self.variables.insert(id, variable);
        self.mirror_add(id);
        id
    }

    pub fn remove_variable(&mut self, id: i32) -> bool {
        if self.variables.remove(&id).is_some() {
            self.mirror_remove(id);
            true
        } else {
            false
        }
    }

    pub fn set_variable(&mut self, id: i32, value: serde_json::Value) {
        self.variables.insert(id, value);
        self.mirror_update(id);
    }

    pub fn get_variable(&self, id: i32) -> Option<&serde_json::Value> {
        self.variables.get(&id)
    }

    /// Whole-model save shape: a list of `{ "variable": <variable> }`, sorted by id.
    #[allow(dead_code)]
    pub fn serialize(&self) -> serde_json::Value {
        let mut ids: Vec<&i32> = self.variables.keys().collect();
        ids.sort();
        let list: Vec<serde_json::Value> = ids
            .into_iter()
            .map(|id| serde_json::json!({ "variable": self.variables[id] }))
            .collect();
        serde_json::Value::Array(list)
    }

    /// Load from the `serialize()` shape, mirroring `VariableManager:load`:
    /// reset the id counter, then re-add each `{ variable }`.
    #[allow(dead_code)]
    pub fn load(&mut self, data: &serde_json::Value) {
        self.variables.clear();
        self.variable_id_count = 0;
        if let Some(list) = data.as_array() {
            for kv in list {
                if let Some(variable) = kv.get("variable") {
                    self.add_variable(variable.clone());
                }
            }
        }
    }

    /// Drop all variables (the Lua `VariableManager:clear`).
    #[allow(dead_code)]
    pub fn clear(&mut self) {
        let ids: Vec<i32> = self.variables.keys().copied().collect();
        for id in ids {
            self.remove_variable(id);
        }
        self.variable_id_count = 0;
    }

    fn mirror_add(&self, id: i32) {
        if let Some(variable) = self.variables.get(&id) {
            lua_bridge::rules_command(
                &self.interface,
                serde_json::json!({
                    "className": "WidgetAddVariableCommand",
                    "id": id,
                    "value": variable,
                }),
            );
        }
    }

    fn mirror_remove(&self, id: i32) {
        lua_bridge::rules_command(
            &self.interface,
            serde_json::json!({
                "className": "WidgetRemoveVariableCommand",
                "id": id,
            }),
        );
    }

    fn mirror_update(&self, id: i32) {
        if let Some(variable) = self.variables.get(&id) {
            lua_bridge::rules_command(
                &self.interface,
                serde_json::json!({
                    "className": "WidgetUpdateVariableCommand",
                    "variable": variable,
                }),
            );
        }
    }
}
