/// A heightmap grid: `heights` in row-major order, `width * height` values.
#[derive(Debug)]
pub(crate) struct Heightmap {
    pub width: usize,
    pub height: usize,
    pub heights: Vec<f32>,
}
