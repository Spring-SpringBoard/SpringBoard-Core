use spring_native::prelude::NativeInterfaceRef;

use super::super::graphics::{self, Texture};

const MAX_CACHE: usize = 20;

struct CachedTexture {
    /// The source texture this is a cached copy of.
    name: Texture,
    texture: Texture,
}

/// FBO copies of brush/pattern textures, so paint passes sample a stable copy.
pub(crate) struct TextureCache {
    interface: NativeInterfaceRef,
    cache: Vec<CachedTexture>,
}

impl TextureCache {
    pub(super) fn new(interface: NativeInterfaceRef) -> Self {
        TextureCache {
            interface,
            cache: Vec::new(),
        }
    }

    pub(crate) fn cache(&mut self, name: &Texture) {
        if self.cache.iter().any(|c| c.name == *name) {
            return;
        }
        let (w, h) = match self.interface.gfx().texture_info(name) {
            Ok((x, y, ..)) if x > 0 && y > 0 => (x, y),
            _ => return,
        };
        if self.cache.len() > MAX_CACHE {
            let old = self.cache.remove(0);
            let _ = self.interface.gfx().delete_texture(&old.texture);
        }
        let Some(tex) = graphics::create_repeating_fbo_texture(&self.interface, w, h) else {
            return;
        };
        graphics::blit(&self.interface, name, &tex);
        self.cache.push(CachedTexture {
            name: name.clone(),
            texture: tex,
        });
    }

    /// The cached copy of `name`, or `name` itself if not cached.
    pub(crate) fn get(&self, name: &Texture) -> Texture {
        self.cache
            .iter()
            .find(|c| c.name == *name)
            .map(|c| c.texture.clone())
            .unwrap_or_else(|| name.clone())
    }
}
