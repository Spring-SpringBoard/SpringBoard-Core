use std::collections::HashSet;

use crate::sbc::command_system::command::Command;
use crate::sbc::grass::commands::terrain_grass_command::{Opts, TerrainGrassCommand};
use crate::sbc::states::state::StateContext;
use crate::sbc::states::{BrushButton, BrushSettings, BrushStamp, MapBrush};

pub(crate) static GRASS: Grass = Grass;
pub(crate) struct Grass;

impl MapBrush for Grass {
    fn name(&self) -> &'static str {
        "grass"
    }
    fn prepare(
        &self,
        brush: &BrushSettings,
        uploaded: &mut HashSet<String>,
        ctx: &mut StateContext,
    ) -> bool {
        crate::sbc::heightmap::brushes::prepare_pattern(brush, uploaded, ctx)
    }

    fn command(
        &self,
        brush: &BrushSettings,
        stamp: BrushStamp,
        button: BrushButton,
    ) -> Box<dyn Command> {
        Box::new(TerrainGrassCommand::new(Opts {
            rotation: stamp.rotation,
            x: stamp.x + stamp.size / 2.0,
            z: stamp.z + stamp.size / 2.0,
            shape_name: brush.pattern_texture.clone().unwrap_or_default(),
            amount: if button.is_secondary() { 0.0 } else { 1.0 },
            size: stamp.size,
        }))
    }
}
