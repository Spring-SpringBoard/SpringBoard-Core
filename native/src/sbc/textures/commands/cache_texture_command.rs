use log::debug;
use serde::Deserialize;

use crate::sbc::command_system::command::Command;
use crate::sbc::command_system::context::Context;
use crate::sbc::command_system::registry::register_command;
use crate::sbc::textures::model::graphics::Texture;
use crate::sbc::textures::TextureModel;

/// Prepares brush and pattern textures for paint passes.
#[derive(Deserialize, Debug)]
pub struct CacheTextureCommand {
    texture: TexturePayload,
}

impl Command for CacheTextureCommand {
    fn execute(&mut self, ctx: &mut Context) {
        let names = self.texture.names();
        debug!("CacheTextureCommand: {:?}", names);
        let tm = ctx.model::<TextureModel>();
        for name in names {
            tm.cache.cache(name);
        }
    }

    fn undoable(&self) -> bool {
        false
    }
}

#[derive(Deserialize, Debug)]
#[serde(untagged)]
enum TexturePayload {
    Names(Vec<Texture>),
    Material(std::collections::BTreeMap<String, Texture>),
}

impl TexturePayload {
    fn names(&self) -> Vec<&Texture> {
        match self {
            TexturePayload::Names(names) => names.iter().collect(),
            TexturePayload::Material(material) => material.values().collect(),
        }
    }
}

register_command!(CacheTextureCommand, "CacheTextureCommand");
