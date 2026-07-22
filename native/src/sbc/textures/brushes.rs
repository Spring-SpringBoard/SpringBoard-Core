use crate::sbc::command_system::command::Command;
use crate::sbc::states::{BrushButton, BrushSettings, BrushStamp, MapBrush};
use crate::sbc::textures::commands::terrain_change_texture_command::{
    Opts, TerrainChangeTextureCommand,
};

pub(crate) static TEXTURE: Texture = Texture;
pub(crate) struct Texture;

impl MapBrush for Texture {
    fn name(&self) -> &'static str {
        "texture"
    }
    fn is_ready(&self, brush: &BrushSettings) -> bool {
        brush.texture_paint_mode != "paint" || !brush.brush_textures.is_empty()
    }

    fn command(
        &self,
        brush: &BrushSettings,
        stamp: BrushStamp,
        button: BrushButton,
    ) -> Box<dyn Command> {
        let action = if button.is_secondary() { -1.0 } else { 1.0 };
        let enabled = &brush.texture_enabled;
        Box::new(TerrainChangeTextureCommand::new(Opts {
            x: stamp.x - stamp.size / 2.0,
            z: stamp.z - stamp.size / 2.0,
            size: stamp.size,
            paint_mode: brush.texture_paint_mode.clone(),
            pattern_texture: brush.pattern_texture.clone().unwrap_or_default().into(),
            pattern_rotation: stamp.rotation.to_radians(),
            brush_texture: serde_json::to_value(&brush.brush_textures).unwrap_or_default(),
            extra: serde_json::json!({
                "diffuseEnabled": enabled.get("diffuse").copied().unwrap_or(false),
                "specularEnabled": enabled.get("specular").copied().unwrap_or(false),
                "emissionEnabled": enabled.get("emission").copied().unwrap_or(false),
                "reflEnabled": enabled.get("refl").copied().unwrap_or(false),
            }),
            mode: brush.mode.clone(),
            kernel_mode: brush.kernel_mode.clone(),
            tex_scale: brush.tex_scale,
            rotation: brush.tex_rotation.to_radians(),
            tex_offset_x: brush.tex_offset_x,
            tex_offset_y: brush.tex_offset_y,
            diffuse_color: brush.diffuse_color,
            falloff_factor: brush.falloff_factor,
            feature_factor: brush.feature_factor,
            strength: brush.strength,
            value: brush.value,
            void_factor: brush.void_factor * action,
            color_index: (brush.color_index as f32 * action) as i32,
            exclusive: if brush.exclusive { 1 } else { 0 },
            ..Default::default()
        }))
    }
}
