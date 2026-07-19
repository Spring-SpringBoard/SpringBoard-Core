use std::path::{Path, PathBuf};

use log::{error, info};
use serde::{Deserialize, Serialize};

use crate::sbc::command_system::command::Command;
use crate::sbc::command_system::context::Context;
use crate::sbc::command_system::registry::register_command;
use crate::sbc::textures::model::TextureModel;
use crate::sbc::textures::ops::import;

#[derive(Deserialize, Serialize, Debug)]
pub struct ImportShadingImageCommand {
    #[serde(rename = "texType")]
    tex_type: String,
    #[serde(rename = "texturePath")]
    texture_path: String,
}

impl ImportShadingImageCommand {
    /// Construct from a fields payload (`texType`, `texturePath`). Transitional:
    /// becomes a typed constructor per docs/porting/todo.md (concrete-commands).
    pub(crate) fn from_fields(fields: serde_json::Value) -> Option<Self> {
        serde_json::from_value(fields).ok()
    }
}

impl Command for ImportShadingImageCommand {
    fn serialize_log(&self) -> serde_json::Value {
        serde_json::to_value(self).unwrap_or(serde_json::Value::Null)
    }

    fn execute(&mut self, ctx: &mut Context) {
        let interface = *ctx.interface;
        let (path, temporary) = if PathBuf::from(&self.texture_path).is_file() {
            (PathBuf::from(&self.texture_path), None)
        } else {
            match interface
                .vfs()
                .get_file_absolute_path(&self.texture_path, "r")
            {
                Ok(Some(path)) => (PathBuf::from(path), None),
                _ => match interface.vfs().load_file(&self.texture_path, "") {
                    Ok(bytes) => {
                        let filename = Path::new(&self.texture_path)
                            .file_name()
                            .and_then(|name| name.to_str())
                            .unwrap_or("shading-texture.png");
                        let path = std::env::temp_dir()
                            .join(format!("sbc-shading-{}-{filename}", std::process::id()));
                        if let Err(err) = std::fs::write(&path, bytes) {
                            error!(
                                "materialize VFS shading {} at {} failed: {err}",
                                self.texture_path,
                                path.display()
                            );
                            return;
                        }
                        (path.clone(), Some(path))
                    }
                    Err(err) => {
                        error!("resolve VFS shading {} failed: {err:?}", self.texture_path);
                        return;
                    }
                },
            }
        };
        match import::import_shading(
            &interface,
            ctx.model::<TextureModel>(),
            &self.tex_type,
            &path,
        ) {
            Ok(()) => info!("import shading {}: {}", self.tex_type, path.display()),
            Err(err) => error!("import shading failed for {}: {err}", path.display()),
        }
        if let Some(path) = temporary {
            let _ = std::fs::remove_file(path);
        }
    }

    fn undoable(&self) -> bool {
        false
    }
}

register_command!(ImportShadingImageCommand, "ImportShadingImageCommand");
