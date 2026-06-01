use std::collections::HashMap;

pub struct GreyscaleShape {
    pub size_x: usize,
    pub size_z: usize,
    pub res: Vec<f32>,
}

pub struct TerrainManager {
    pub shapes: HashMap<String, GreyscaleShape>,
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
