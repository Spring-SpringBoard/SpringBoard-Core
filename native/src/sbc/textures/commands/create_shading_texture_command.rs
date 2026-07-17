use crate::sbc::command_system::command::Command;
use crate::sbc::command_system::context::Context;
use crate::sbc::command_system::registry::register_command;
use crate::sbc::textures::TextureModel;

/// Create a blank editor-owned shading texture with the requested dimensions.
#[derive(serde::Deserialize)]
pub(crate) struct CreateShadingTextureCommand {
    name: String,
    width: i32,
    height: i32,
    color: [f32; 4],
}

impl CreateShadingTextureCommand {
    pub(crate) fn new(name: impl Into<String>, width: i32, height: i32, color: [f32; 4]) -> Self {
        Self {
            name: name.into(),
            width,
            height,
            color,
        }
    }
}

impl Command for CreateShadingTextureCommand {
    fn execute(&mut self, ctx: &mut Context) {
        ctx.model::<TextureModel>()
            .shading
            .create(&self.name, self.width, self.height, self.color);
    }

    fn undoable(&self) -> bool {
        false
    }
}

register_command!(CreateShadingTextureCommand, "CreateShadingTextureCommand");
