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
        let id = ctx.current_command_id;
        let tm = ctx.model::<TextureModel>();
        if tm.history.has_redo(id) {
            tm.history.redo_stroke(Some(id));
            return;
        }
        let Some((_, tiles_x, tiles_z)) = tm.tiles.grid() else {
            error!("import diffuse: could not initialize tile store");
            return;
        };
        tm.history
            .back_up_region(&tm.tiles, 0.0, 0.0, tiles_x as f32, tiles_z as f32);
        match import::import_diffuse(&interface, tm, &path) {
            Ok(()) => {
                tm.history.push_stack(Some(id));
                info!("import diffuse: {}", path.display());
                ctx.model::<NotificationManager>().info(
                    "import",
                    "Imported",
                    "Diffuse texture imported",
                );
            }
            Err(err) => {
                tm.history.abort_active();
                error!("import diffuse failed for {}: {err}", path.display());
                ctx.model::<NotificationManager>()
                    .warn("import", &format!("Diffuse import failed: {err}"));
            }
        }
    }

    fn undoable(&self) -> bool {
        true
    }

    fn unexecute(&mut self, ctx: &mut Context) {
        let id = ctx.current_command_id;
        ctx.model::<TextureModel>().history.pop_stack(Some(id));
    }
}

register_command!(ImportDiffuseCommand, "ImportDiffuseCommand");
