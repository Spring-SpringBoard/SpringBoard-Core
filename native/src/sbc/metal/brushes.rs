use std::collections::HashSet;

use crate::sbc::command_system::command::Command;
use crate::sbc::metal::commands::terrain_metal_command::{Opts, TerrainMetalCommand};
use crate::sbc::states::state::StateContext;
use crate::sbc::states::{BrushButton, BrushSettings, BrushStamp, MapBrush};

pub(crate) static METAL: Metal = Metal;
pub(crate) struct Metal;

impl MapBrush for Metal {
    fn name(&self) -> &'static str {
        "metal"
    }
    fn initial_delay(&self) -> f32 {
        0.0
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
        Box::new(TerrainMetalCommand::new(Opts {
            rotation: stamp.rotation,
            x: stamp.x + stamp.size / 2.0,
            z: stamp.z + stamp.size / 2.0,
            shape_name: brush.pattern_texture.clone().unwrap_or_default(),
            amount: if button.is_secondary() {
                0.0
            } else {
                brush.amount
            },
            size: stamp.size,
        }))
    }
}
