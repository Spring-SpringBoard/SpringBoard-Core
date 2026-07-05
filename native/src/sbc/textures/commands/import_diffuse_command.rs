use std::path::PathBuf;

use log::{error, info};
use serde::Deserialize;

use crate::sbc::command_system::command::Command;
use crate::sbc::command_system::context::Context;
use crate::sbc::command_system::registry::register_command;
use crate::sbc::textures::model::TextureModel;
use crate::sbc::textures::ops::import;

#[derive(Deserialize, Debug)]
pub struct ImportDiffuseCommand {
    #[serde(rename = "texturePath")]
    texture_path: String,
}

impl Command for ImportDiffuseCommand {
    fn execute(&mut self, ctx: &mut Context) {
        let path = PathBuf::from(&self.texture_path);
        let interface = *ctx.interface;
        match import::import_diffuse(&interface, ctx.model::<TextureModel>(), &path) {
            Ok(()) => info!("import diffuse: {}", path.display()),
            Err(err) => error!("import diffuse failed for {}: {err}", path.display()),
        }
    }

    fn undoable(&self) -> bool {
        false
    }
}

register_command!(ImportDiffuseCommand, "ImportDiffuseCommand");
