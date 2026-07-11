use serde::Deserialize;

use crate::sbc::command_system::command::Command;
use crate::sbc::command_system::context::Context;
use crate::sbc::command_system::registry::register_command;
use crate::sbc::textures::TextureModel;

#[derive(Deserialize, Debug)]
pub struct SetMapShadingTextureEnabledCommand {
    opts: ShadingTextureEnabled,
}

#[derive(Deserialize, Debug)]
struct ShadingTextureEnabled {
    name: String,
    value: bool,
}

impl Command for SetMapShadingTextureEnabledCommand {
    fn execute(&mut self, ctx: &mut Context) {
        ctx.model::<TextureModel>()
            .shading
            .set_enabled(&self.opts.name, self.opts.value);
    }

    fn undoable(&self) -> bool {
        false
    }
}

register_command!(
    SetMapShadingTextureEnabledCommand,
    "SetMapShadingTextureEnabledCommand"
);
