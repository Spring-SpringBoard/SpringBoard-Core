use std::collections::HashSet;

use crate::sbc::command_system::command::Command;
use crate::sbc::heightmap::commands::set_heightmap_brush_command::SetHeightmapBrushCommand;
use crate::sbc::heightmap::commands::terrain_level_command::{
    Opts as LevelOpts, TerrainLevelCommand,
};
use crate::sbc::heightmap::commands::terrain_shape_modify_command::{
    Opts as ShapeOpts, TerrainShapeModifyCommand,
};
use crate::sbc::heightmap::commands::terrain_smooth_command::{
    Opts as SmoothOpts, TerrainSmoothCommand,
};
use crate::sbc::states::shapes::{brush_opts, load_shape};
use crate::sbc::states::state::StateContext;
use crate::sbc::states::{BrushButton, BrushSettings, BrushStamp, MapBrush};

pub(crate) static SHAPE_MODIFY: ShapeModify = ShapeModify;
pub(crate) static LEVEL: Level = Level;
pub(crate) static SMOOTH: Smooth = Smooth;

pub(crate) struct ShapeModify;
pub(crate) struct Level;
pub(crate) struct Smooth;

pub(crate) fn prepare_pattern(
    brush: &BrushSettings,
    uploaded: &mut HashSet<String>,
    ctx: &mut StateContext,
) -> bool {
    let Some(pattern) = brush.pattern_texture.as_deref() else {
        return false;
    };
    if uploaded.contains(pattern) {
        return true;
    }
    let Some(shape) = load_shape(ctx.interface, pattern) else {
        log::warn!("heightmap brush pattern {pattern} could not be loaded");
        return false;
    };
    ctx.command(Box::new(SetHeightmapBrushCommand::new(brush_opts(
        pattern, &shape,
    ))));
    uploaded.insert(pattern.to_string());
    true
}

fn centre(stamp: BrushStamp) -> (f32, f32) {
    (stamp.x + stamp.size / 2.0, stamp.z + stamp.size / 2.0)
}

fn signed_strength(brush: &BrushSettings, button: BrushButton) -> f32 {
    if button.is_secondary() {
        -brush.strength
    } else {
        brush.strength
    }
}

impl MapBrush for ShapeModify {
    fn name(&self) -> &'static str {
        "terrain-shape-modify"
    }

    fn prepare(
        &self,
        brush: &BrushSettings,
        uploaded: &mut HashSet<String>,
        ctx: &mut StateContext,
    ) -> bool {
        prepare_pattern(brush, uploaded, ctx)
    }

    fn command(
        &self,
        brush: &BrushSettings,
        stamp: BrushStamp,
        button: BrushButton,
    ) -> Box<dyn Command> {
        let (x, z) = centre(stamp);
        Box::new(TerrainShapeModifyCommand::new(ShapeOpts {
            rotation: stamp.rotation,
            x,
            z,
            shape_name: brush.pattern_texture.clone().unwrap_or_default(),
            strength: signed_strength(brush, button),
            size: stamp.size,
        }))
    }
}

impl MapBrush for Level {
    fn name(&self) -> &'static str {
        "terrain-level"
    }

    fn prepare(
        &self,
        brush: &BrushSettings,
        uploaded: &mut HashSet<String>,
        ctx: &mut StateContext,
    ) -> bool {
        prepare_pattern(brush, uploaded, ctx)
    }

    fn consume_press(&self, brush: &mut BrushSettings, button: BrushButton, height: f32) -> bool {
        if button.is_secondary() {
            brush.set_height(height);
            true
        } else {
            false
        }
    }

    fn command(
        &self,
        brush: &BrushSettings,
        stamp: BrushStamp,
        button: BrushButton,
    ) -> Box<dyn Command> {
        let (x, z) = centre(stamp);
        Box::new(TerrainLevelCommand::new(LevelOpts {
            rotation: stamp.rotation,
            x,
            z,
            shape_name: brush.pattern_texture.clone().unwrap_or_default(),
            strength: signed_strength(brush, button),
            size: stamp.size,
            height: brush.height,
            apply_dir_id: brush.apply_dir.id(),
        }))
    }
}

impl MapBrush for Smooth {
    fn name(&self) -> &'static str {
        "terrain-smooth"
    }

    fn prepare(
        &self,
        brush: &BrushSettings,
        uploaded: &mut HashSet<String>,
        ctx: &mut StateContext,
    ) -> bool {
        prepare_pattern(brush, uploaded, ctx)
    }

    fn command(
        &self,
        brush: &BrushSettings,
        stamp: BrushStamp,
        button: BrushButton,
    ) -> Box<dyn Command> {
        let (x, z) = centre(stamp);
        let strength = signed_strength(brush, button).abs();
        let sigma = (strength.sqrt().sqrt() / 2.0).clamp(0.20, 1.5);
        Box::new(TerrainSmoothCommand::new(SmoothOpts {
            rotation: stamp.rotation,
            x,
            z,
            shape_name: brush.pattern_texture.clone().unwrap_or_default(),
            strength,
            size: stamp.size,
            sigma,
        }))
    }
}
