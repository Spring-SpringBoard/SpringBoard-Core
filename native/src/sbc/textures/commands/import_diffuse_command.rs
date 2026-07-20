use std::path::PathBuf;

use log::{error, info};
use serde::Deserialize;

use crate::sbc::command_system::command::Command;
use crate::sbc::command_system::context::Context;
use crate::sbc::command_system::registry::register_command;
use crate::sbc::notifications::NotificationManager;
use crate::sbc::textures::model::TextureModel;
use crate::sbc::textures::ops::import;

#[derive(Deserialize, Debug)]
pub struct ImportDiffuseCommand {
    #[serde(rename = "texturePath")]
    texture_path: String,
}

impl ImportDiffuseCommand {
    pub(crate) fn new(texture_path: String) -> Self {
        Self { texture_path }
    }
}

impl Command for ImportDiffuseCommand {
    fn execute(&mut self, ctx: &mut Context) {
        let path = PathBuf::from(&self.texture_path);
        let interface = *ctx.interface;
        match import::import_diffuse(&interface, ctx.model::<TextureModel>(), &path) {
            Ok(()) => {
                info!("import diffuse: {}", path.display());
                ctx.model::<NotificationManager>().info(
                    "import",
                    "Imported",
                    "Diffuse texture imported",
                );
            }
            Err(err) => {
                error!("import diffuse failed for {}: {err}", path.display());
                ctx.model::<NotificationManager>()
                    .warn("import", &format!("Diffuse import failed: {err}"));
            }
        }
    }

    fn undoable(&self) -> bool {
        false
    }
}

register_command!(ImportDiffuseCommand, "ImportDiffuseCommand");
