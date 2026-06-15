use super::super::graphics::Texture;
use super::super::texture_drawing::TexCoordOpts;

/// Diffuse blend mode (maps to a GLSL expression in `shared::blend_mode_expr`).
#[derive(Clone, Copy, Debug, Default)]
pub(crate) enum BlendMode {
    #[default]
    Normal,
    Add,
    ColorBurn,
    ColorDodge,
    Color,
    Darken,
    Difference,
    Exclusion,
    HardLight,
    InverseDifference,
    Lighten,
    Luminance,
    Multiply,
    Overlay,
    Premultiplied,
    Screen,
    SoftLight,
    Subtract,
}

impl BlendMode {
    pub(crate) fn from_name(name: &str) -> Self {
        match name {
            "" | "Normal" => Self::Normal,
            "Add" => Self::Add,
            "ColorBurn" => Self::ColorBurn,
            "ColorDodge" => Self::ColorDodge,
            "Color" => Self::Color,
            "Darken" => Self::Darken,
            "Difference" => Self::Difference,
            "Exclusion" => Self::Exclusion,
            "HardLight" => Self::HardLight,
            "InverseDifference" => Self::InverseDifference,
            "Lighten" => Self::Lighten,
            "Luminance" => Self::Luminance,
            "Multiply" => Self::Multiply,
            "Overlay" => Self::Overlay,
            "Premultiplied" => Self::Premultiplied,
            "Screen" => Self::Screen,
            "SoftLight" => Self::SoftLight,
            "Subtract" => Self::Subtract,
            other => {
                log::warn!("unknown blend mode {other}, using Normal");
                Self::Normal
            }
        }
    }
}

/// Convolution kernel for the blur/filter pass.
#[derive(Clone, Copy, Debug, Default)]
pub(crate) enum KernelMode {
    #[default]
    Blur,
    BottomSobel,
    Emboss,
    LeftSobel,
    Outline,
    RightSobel,
    Sharpen,
    TopSobel,
}

impl KernelMode {
    pub(crate) fn from_name(name: &str) -> Self {
        match name {
            "blur" => Self::Blur,
            "bottom_sobel" => Self::BottomSobel,
            "emboss" => Self::Emboss,
            "left_sobel" => Self::LeftSobel,
            "outline" => Self::Outline,
            "right_sobel" => Self::RightSobel,
            "sharpen" => Self::Sharpen,
            "top sobel" => Self::TopSobel,
            other => {
                log::warn!("unknown kernel mode {other}, using blur");
                Self::Blur
            }
        }
    }
}

/// A square paint region. Tile-space (`region / TEXTURE_SIZE`) for the per-tile
/// passes (paint / void / blur / height); world-space for the per-shading-tex
/// passes.
#[derive(Clone, Copy, Debug)]
pub(crate) struct Region {
    pub x: f32,
    pub z: f32,
    pub size: f32,
}

impl Region {
    pub(crate) fn end_x(self) -> f32 {
        self.x + self.size
    }
    pub(crate) fn end_z(self) -> f32 {
        self.z + self.size
    }
}

/// Paint options forwarded by `TerrainChangeTextureCommand`. Fields default so
/// shader passes that don't read a uniform can ignore it.
#[derive(Default, Clone, Debug)]
pub(crate) struct PaintOptions {
    pub diffuse_color: [f32; 4],
    pub strength: f32,
    pub falloff_factor: f32,
    pub feature_factor: f32,
    pub void_factor: f32,
    pub pattern_rotation: f32,
    pub mode: BlendMode,
    pub kernel_mode: KernelMode,
    pub pattern_texture: Texture,
    pub brush_diffuse: Option<Texture>,
    /// Map of shading-tex name to brush texture.
    pub brush_shading: Vec<(String, Texture)>,
    pub shading_textures: Vec<(String, Texture)>,
    /// Map of shading-tex name to enabled flag.
    pub shading_enabled: Vec<(String, bool)>,
    pub diffuse_enabled: bool,
    pub tex_offset_x: f32,
    pub tex_offset_y: f32,
    pub tex_scale: f32,
    pub texture_rotation: f32,
    pub color_index: i32,
    pub exclusive: i32,
    pub value: f32,
}

impl PaintOptions {
    pub(super) fn tex_coord_opts(&self) -> TexCoordOpts {
        TexCoordOpts {
            tex_offset_x: self.tex_offset_x,
            tex_offset_y: self.tex_offset_y,
            tex_scale: self.tex_scale,
            rotation: self.texture_rotation,
        }
    }

    pub(super) fn shading_enabled_for(&self, ty: &str) -> bool {
        self.shading_enabled
            .iter()
            .find(|(n, _)| n == ty)
            .map(|(_, e)| *e)
            .unwrap_or(false)
    }

    pub(super) fn shading_source_for(&self, ty: &str) -> Option<&Texture> {
        self.shading_textures
            .iter()
            .find(|(n, _)| n == ty)
            .map(|(_, texture)| texture)
    }
}
