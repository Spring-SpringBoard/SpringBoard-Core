use log::debug;
use serde::Deserialize;

use crate::sbc::command_system::command::Command;
use crate::sbc::command_system::context::Context;
use crate::sbc::command_system::registry::register_command;
use crate::sbc::textures::model::draw::{
    paint_diffuse, paint_dnts, paint_filter, paint_height, paint_shading_textures, paint_void,
    BlendMode, KernelMode, PaintOptions, Region,
};
use crate::sbc::textures::model::graphics::Texture;
use crate::sbc::textures::TextureModel;

/// Paints the map diffuse texture (and, for `paint` mode, the shading textures)
/// under the brush. Not undoable itself; a stroke is closed/undone/redone as one
/// unit by the merged texture command.
#[derive(Deserialize, Debug)]
pub struct TerrainChangeTextureCommand {
    opts: Opts,
}

#[derive(Deserialize, Debug, Default)]
struct Opts {
    x: f32,
    z: f32,
    size: f32,

    #[serde(rename = "paintMode", default)]
    paint_mode: String,
    #[serde(default)]
    mode: String,
    #[serde(rename = "kernelMode", default)]
    kernel_mode: String,

    #[serde(rename = "patternRotation", default)]
    pattern_rotation: f32,
    #[serde(rename = "diffuseColor", default = "default_color")]
    diffuse_color: [f32; 4],
    #[serde(default = "default_strength")]
    strength: f32,
    #[serde(rename = "falloffFactor", default)]
    falloff_factor: f32,
    #[serde(rename = "featureFactor", default)]
    feature_factor: f32,
    #[serde(rename = "voidFactor", default)]
    void_factor: f32,

    #[serde(rename = "patternTexture", default)]
    pattern_texture: Texture,
    /// Brush-texture paths keyed by channel name (`diffuse`, `specular`, ...).
    #[serde(rename = "brushTexture", default)]
    brush_texture: serde_json::Value,
    #[serde(rename = "shadingTexture", default)]
    shading_texture: serde_json::Value,

    /// `<channel>Enabled` flags (`diffuseEnabled`, ...), collected via the
    /// catch-all to avoid enumerating every shading-tex name here.
    #[serde(default, flatten)]
    extra: serde_json::Value,

    #[serde(rename = "texOffsetX", default)]
    tex_offset_x: f32,
    #[serde(rename = "texOffsetY", default)]
    tex_offset_y: f32,
    #[serde(rename = "texScale", default = "default_one")]
    tex_scale: f32,
    /// Already in radians.
    #[serde(default)]
    rotation: f32,

    #[serde(rename = "colorIndex", default)]
    color_index: i32,
    #[serde(default)]
    exclusive: i32,
    #[serde(default)]
    value: f32,
}

impl Command for TerrainChangeTextureCommand {
    fn execute(&mut self, ctx: &mut Context) {
        let o = &self.opts;
        debug!(
            "TerrainChangeTextureCommand: mode={} ({}, {}) size {}",
            o.paint_mode, o.x, o.z, o.size
        );

        let world_region = self.world_region();
        let mut paint = self.build_paint_options();
        if o.paint_mode == "paint" {
            // Shading textures cover the whole map, so their pass uses
            // world-space coordinates instead of tile-space coordinates.
            paint.diffuse_enabled =
                paint.diffuse_enabled || self.flag(&self.opts.extra, "diffuseEnabled");
        }

        let interface = *ctx.interface;
        let tm = ctx.model::<TextureModel>();

        // First paint generates + binds the editable atlas (idempotent).
        if !tm.tiles.generate() {
            return;
        }
        tm.shading.generate_all();

        let texture_size = tm.tiles.texture_size() as f32;
        let tile_region = Region {
            x: world_region.x / texture_size,
            z: world_region.z / texture_size,
            size: world_region.size / texture_size,
        };

        match o.paint_mode.as_str() {
            "void" => paint_void(&interface, tm, tile_region, &paint),
            "blur" => paint_filter(&interface, tm, tile_region, &paint),
            "height" => paint_height(&interface, tm, tile_region, &paint),
            "paint" => {
                paint_diffuse(&interface, tm, tile_region, &paint);
                paint_shading_textures(&interface, tm, world_region, &paint);
            }
            "dnts" => paint_dnts(&interface, tm, world_region, &paint),
            "" => debug!("TerrainChangeTextureCommand: no paintMode, skipping"),
            other => log::error!("TerrainChangeTextureCommand: unknown paintMode {other}"),
        }
    }

    fn undoable(&self) -> bool {
        // The stroke is undone as a unit by TerrainChangeTextureMergedCommand.
        false
    }
}

impl TerrainChangeTextureCommand {
    /// Rotate the brush rect, axis-align it, return the world-space region.
    fn world_region(&self) -> Region {
        let o = &self.opts;
        let sh = o.size / 2.0;
        let corners = [
            rotate(-sh, sh, o.pattern_rotation),
            rotate(sh, sh, o.pattern_rotation),
            rotate(sh, -sh, o.pattern_rotation),
            rotate(-sh, -sh, o.pattern_rotation),
        ];
        let xs: Vec<f32> = corners.iter().map(|c| c.0 + o.x + sh).collect();
        let zs: Vec<f32> = corners.iter().map(|c| c.1 + o.z + sh).collect();
        let min_x = xs.iter().cloned().fold(f32::INFINITY, f32::min);
        let max_x = xs.iter().cloned().fold(f32::NEG_INFINITY, f32::max);
        let min_z = zs.iter().cloned().fold(f32::INFINITY, f32::min);
        let size = max_x - min_x;
        Region {
            x: min_x,
            z: min_z,
            size,
        }
    }

    fn build_paint_options(&self) -> PaintOptions {
        let o = &self.opts;
        let mut paint = PaintOptions {
            diffuse_color: o.diffuse_color,
            strength: o.strength,
            falloff_factor: o.falloff_factor,
            feature_factor: o.feature_factor,
            void_factor: o.void_factor,
            pattern_rotation: o.pattern_rotation,
            mode: BlendMode::from_name(&o.mode),
            kernel_mode: KernelMode::from_name(&o.kernel_mode),
            pattern_texture: o.pattern_texture.clone(),
            brush_diffuse: None,
            brush_shading: Vec::new(),
            shading_textures: Vec::new(),
            shading_enabled: Vec::new(),
            diffuse_enabled: false,
            tex_offset_x: o.tex_offset_x,
            tex_offset_y: o.tex_offset_y,
            tex_scale: o.tex_scale,
            texture_rotation: o.rotation,
            color_index: o.color_index,
            exclusive: o.exclusive,
            value: o.value,
        };

        if let Some(obj) = o.brush_texture.as_object() {
            for (k, v) in obj {
                if let Some(s) = v.as_str() {
                    if k == "diffuse" {
                        paint.brush_diffuse = Some(Texture::from(s.to_string()));
                    } else {
                        paint.brush_shading.push((k.clone(), Texture::from(s.to_string())));
                    }
                }
            }
        }
        if let Some(obj) = o.shading_texture.as_object() {
            for (k, v) in obj {
                if let Some(s) = v.as_str() {
                    paint.shading_textures.push((k.clone(), Texture::from(s.to_string())));
                }
            }
        }

        paint.diffuse_enabled = self.flag(&o.extra, "diffuseEnabled");
        for channel in ["specular", "emission", "refl", "splat_distr", "detail"] {
            let key = format!("{channel}Enabled");
            paint
                .shading_enabled
                .push((channel.to_string(), self.flag(&o.extra, &key)));
        }

        paint
    }

    fn flag(&self, extra: &serde_json::Value, key: &str) -> bool {
        extra
            .as_object()
            .and_then(|m| m.get(key))
            .and_then(|v| v.as_bool())
            .unwrap_or(false)
    }
}

fn rotate(x: f32, y: f32, angle: f32) -> (f32, f32) {
    (
        x * angle.cos() - y * angle.sin(),
        x * angle.sin() + y * angle.cos(),
    )
}

fn default_color() -> [f32; 4] {
    [1.0, 1.0, 1.0, 1.0]
}

fn default_strength() -> f32 {
    1.0
}

fn default_one() -> f32 {
    1.0
}

register_command!(TerrainChangeTextureCommand, "TerrainChangeTextureCommand");
