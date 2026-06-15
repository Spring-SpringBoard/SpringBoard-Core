use serde::Deserialize;

use crate::sbc::command_system::command::Command;
use crate::sbc::command_system::context::Context;
use crate::sbc::command_system::registry::register_command;
use crate::sbc::textures::TextureModel;

/// Closes one texture stroke into a single undoable history entry. Carries no
/// payload — the registry strips the wire fields, leaving an empty (unit) body.
#[derive(Debug, Deserialize)]
pub struct TerrainChangeTextureMergedCommand;

impl Command for TerrainChangeTextureMergedCommand {
    fn execute(&mut self, ctx: &mut Context) {
        let id = ctx.current_command_id;
        ctx.model::<TextureModel>().history.close_or_redo_stroke(Some(id));
    }

    fn unexecute(&mut self, ctx: &mut Context) {
        let id = ctx.current_command_id;
        ctx.model::<TextureModel>().history.pop_stack(Some(id));
    }
}

register_command!(
    TerrainChangeTextureMergedCommand,
    "TerrainChangeTextureMergedCommand"
);
