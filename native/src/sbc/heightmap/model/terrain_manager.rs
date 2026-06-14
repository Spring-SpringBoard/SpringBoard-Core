use std::any::Any;
use std::collections::HashMap;

use crate::sbc::command_system::model::{Model, ModelFactory};

inventory::submit! { ModelFactory { make: |_| Box::new(TerrainManager::new()) } }

pub struct GreyscaleShape {
    pub size_x: usize,
    pub size_z: usize,
    pub res: Vec<f32>,
}

pub struct TerrainManager {
    pub shapes: HashMap<String, GreyscaleShape>,
}

impl Model for TerrainManager {
    fn as_any_mut(&mut self) -> &mut dyn Any {
        self
    }
}

impl TerrainManager {
    pub fn new() -> TerrainManager {
        TerrainManager {
            shapes: HashMap::new(),
        }
    }
    pub fn get_shape(&self, shape_name: &str) -> Option<&GreyscaleShape> {
        self.shapes.get(shape_name)
    }
}
