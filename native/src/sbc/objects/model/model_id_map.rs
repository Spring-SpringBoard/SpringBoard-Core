use std::collections::HashMap;

/// Maps the editor's stable `modelID` (survives create/destroy) to the engine's
/// `springID` (reassigned on each create), and allocates fresh modelIDs.
#[derive(Default)]
pub struct ModelIdMap {
    model_to_spring: HashMap<i32, i32>,
    spring_to_model: HashMap<i32, i32>,
    model_id_count: i32,
}

impl ModelIdMap {
    pub fn spring_id(&self, model_id: i32) -> Option<i32> {
        self.model_to_spring.get(&model_id).copied()
    }

    pub fn model_id(&self, spring_id: i32) -> Option<i32> {
        self.spring_to_model.get(&spring_id).copied()
    }

    pub fn latest_model_id(&self) -> i32 {
        self.model_id_count
    }

    /// Allocate (or reuse) a modelID for a fresh springID. `model_id` is `Some`
    /// on redo/undo-restore so the object keeps its stable id.
    pub fn register(&mut self, spring_id: i32, model_id: Option<i32>) -> i32 {
        let model_id = model_id.unwrap_or_else(|| {
            self.model_id_count += 1;
            self.model_id_count
        });
        if model_id > self.model_id_count {
            self.model_id_count = model_id;
        }
        self.model_to_spring.insert(model_id, spring_id);
        self.spring_to_model.insert(spring_id, model_id);
        model_id
    }

    pub fn unregister(&mut self, spring_id: i32) {
        if let Some(model_id) = self.spring_to_model.remove(&spring_id) {
            self.model_to_spring.remove(&model_id);
        }
    }
}
