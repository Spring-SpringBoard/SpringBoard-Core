use std::path::PathBuf;

use log::{error, info};
use serde::Deserialize;

use crate::sbc::command_system::command::Command;
use crate::sbc::command_system::context::Context;
use crate::sbc::command_system::registry::register_command;
use crate::sbc::textures::model::TextureModel;
use crate::sbc::textures::ops::import;

#[derive(Deserialize, Debug)]
pub struct ImportShadingImageCommand {
    #[serde(rename = "texType")]
    tex_type: String,
    #[serde(rename = "texturePath")]
    texture_path: String,
}

impl Command for ImportShadingImageCommand {
    fn execute(&mut self, ctx: &mut Context) {
        let path = PathBuf::from(&self.texture_path);
        let interface = *ctx.interface;
        match import::import_shading(
            &interface,
            ctx.model::<TextureModel>(),
            &self.tex_type,
            &path,
        ) {
            Ok(()) => info!("import shading {}: {}", self.tex_type, path.display()),
            Err(err) => error!("import shading failed for {}: {err}", path.display()),
        }
    }

    fn undoable(&self) -> bool {
        false
    }
}

register_command!(ImportShadingImageCommand, "ImportShadingImageCommand");
