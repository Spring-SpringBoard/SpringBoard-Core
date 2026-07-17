use spring_native::prelude::{constants, NativeInterfaceRef};

use super::super::graphics::{self, Texture};
use super::surface::{new_surface, Surface};

/// A snapshot of one shading texture's current state.
pub(crate) struct ShadingTexture {
    pub name: String,
    pub texture: Texture,
    pub width: i32,
    pub height: i32,
    pub dirty: bool,
}

struct ShadingDef {
    name: &'static str,
    engine_name: &'static str,
    bind_type: &'static str,
    slot: i32,
    /// Splat-normal / detail textures need mipmaps regenerated after a write.
    needs_mipmap: bool,
}

const SHADING_DEFS: &[ShadingDef] = &[
    ShadingDef {
        name: "specular",
        engine_name: "$ssmf_specular",
        bind_type: "$ssmf_specular",
        slot: 0,
        needs_mipmap: false,
    },
    ShadingDef {
        name: "emission",
        engine_name: "$ssmf_emission",
        bind_type: "$ssmf_emission",
        slot: 0,
        needs_mipmap: false,
    },
    ShadingDef {
        name: "refl",
        engine_name: "$ssmf_sky_refl",
        bind_type: "$ssmf_sky_refl",
        slot: 0,
        needs_mipmap: false,
    },
    ShadingDef {
        name: "splat_distr",
        engine_name: "$ssmf_splat_distr",
        bind_type: "$ssmf_splat_distr",
        slot: 0,
        needs_mipmap: false,
    },
    ShadingDef {
        name: "splat_normals0",
        engine_name: "$ssmf_splat_normals:0",
        bind_type: "$ssmf_splat_normals",
        slot: 0,
        needs_mipmap: true,
    },
    ShadingDef {
        name: "splat_normals1",
        engine_name: "$ssmf_splat_normals:1",
        bind_type: "$ssmf_splat_normals",
        slot: 1,
        needs_mipmap: true,
    },
    ShadingDef {
        name: "splat_normals2",
        engine_name: "$ssmf_splat_normals:2",
        bind_type: "$ssmf_splat_normals",
        slot: 2,
        needs_mipmap: true,
    },
    ShadingDef {
        name: "splat_normals3",
        engine_name: "$ssmf_splat_normals:3",
        bind_type: "$ssmf_splat_normals",
        slot: 3,
        needs_mipmap: true,
    },
    ShadingDef {
        name: "detail",
        engine_name: "$detail",
        bind_type: "$detail",
        slot: 0,
        needs_mipmap: true,
    },
];

struct ShadingSlot {
    surface: Surface,
    width: i32,
    height: i32,
}

/// The editable shading textures bound back to the engine.
pub(crate) struct ShadingStore {
    interface: NativeInterfaceRef,
    shading: Vec<(String, ShadingSlot)>,
    generated: bool,
}

impl ShadingStore {
    pub(super) fn new(interface: NativeInterfaceRef) -> Self {
        ShadingStore {
            interface,
            shading: Vec::new(),
            generated: false,
        }
    }

    /// Mirror every known shading texture from its engine source (idempotent).
    pub(crate) fn generate_all(&mut self) {
        if self.generated {
            return;
        }
        for def in SHADING_DEFS {
            self.assign(def, &Texture::from(def.engine_name.to_string()));
        }
        self.generated = true;
    }

    /// Mirror a shading texture (from `source`, or its engine default) if not
    /// already present. Returns whether it now exists.
    pub(crate) fn ensure(&mut self, name: &str, source: Option<&Texture>) -> bool {
        if self.surface(name).is_some() {
            return true;
        }
        let Some(def) = SHADING_DEFS.iter().find(|def| def.name == name) else {
            log::debug!("ensure_shading_texture: unknown shading texture {name}");
            return false;
        };
        let default = Texture::from(def.engine_name.to_string());
        self.assign(def, source.unwrap_or(&default));
        self.surface(name).is_some()
    }

    pub(crate) fn names() -> impl Iterator<Item = &'static str> {
        SHADING_DEFS.iter().map(|def| def.name)
    }

    pub(crate) fn set_enabled(&mut self, name: &str, enabled: bool) -> bool {
        if enabled {
            return self.ensure(name, None);
        }
        let Some(def) = SHADING_DEFS.iter().find(|def| def.name == name) else {
            log::debug!("disable_shading_texture: unknown shading texture {name}");
            return false;
        };
        if let Some(index) = self.shading.iter().position(|(n, _)| n == name) {
            let (_, slot) = self.shading.remove(index);
            let texture = slot.surface.borrow().texture.clone();
            let _ = self.interface.gfx().delete_texture(&texture);
        }
        match self.interface.unsynced_ctrl().set_map_shading_texture(
            def.bind_type,
            def.engine_name,
            def.slot,
        ) {
            Ok(true) => true,
            other => {
                log::debug!(
                    "shading {}: reset SetMapShadingTexture({}, slot={}) returned {other:?}",
                    def.name,
                    def.bind_type,
                    def.slot
                );
                false
            }
        }
    }

    pub(crate) fn set_from_source(&mut self, name: &str, source: &Texture, dirty: bool) -> bool {
        if let Some((_, slot)) = self.shading.iter().find(|(n, _)| n == name) {
            let texture = slot.surface.borrow().texture.clone();
            graphics::blit(&self.interface, source, &texture);
            let mut obj = slot.surface.borrow_mut();
            obj.dirty = dirty;
            if obj.needs_mipmap {
                graphics::generate_mipmap(&self.interface, &obj.texture);
            }
            return true;
        }
        let Some(def) = SHADING_DEFS.iter().find(|def| def.name == name) else {
            log::debug!("set_from_source: unknown shading texture {name}");
            return false;
        };
        self.assign(def, source);
        if let Some(surface) = self.surface(name) {
            surface.borrow_mut().dirty = dirty;
        }
        self.surface(name).is_some()
    }

    /// Replace a shading texture with a blank, editor-owned surface.
    ///
    /// This is the native equivalent of Chili's `MakeShadingTextureCommand`:
    /// the temporary FBO is filled first, then copied into the correctly bound
    /// shading slot (which also chooses the required mipmap/wrap settings).
    pub(crate) fn create(&mut self, name: &str, width: i32, height: i32, color: [f32; 4]) -> bool {
        if width <= 0 || height <= 0 || !SHADING_DEFS.iter().any(|def| def.name == name) {
            return false;
        }
        let _ = self.set_enabled(name, false);
        let Some(source) = graphics::create_fbo_texture(&self.interface, width, height) else {
            log::error!("shading {name}: create blank FBO failed ({width}x{height})");
            return false;
        };
        {
            let gfx = self.interface.gfx();
            let _ = gfx.render_to_texture(&source, || {
                let _ = gfx.clear(constants::GL_COLOR_BUFFER_BIT, color, 4);
            });
        }
        let created = self.set_from_source(name, &source, true);
        let _ = self.interface.gfx().delete_texture(&source);
        created
    }

    pub(crate) fn surface(&self, name: &str) -> Option<&Surface> {
        self.shading
            .iter()
            .find(|(n, _)| n == name)
            .map(|(_, slot)| &slot.surface)
    }

    pub(crate) fn texture(&self, name: &str) -> Option<ShadingTexture> {
        self.shading
            .iter()
            .find(|(n, _)| n == name)
            .map(|(_, slot)| ShadingTexture {
                name: name.to_string(),
                texture: slot.surface.borrow().texture.clone(),
                width: slot.width,
                height: slot.height,
                dirty: slot.surface.borrow().dirty,
            })
    }

    pub(crate) fn textures(&self) -> Vec<ShadingTexture> {
        self.shading
            .iter()
            .map(|(name, slot)| {
                let obj = slot.surface.borrow();
                ShadingTexture {
                    name: name.clone(),
                    texture: obj.texture.clone(),
                    width: slot.width,
                    height: slot.height,
                    dirty: obj.dirty,
                }
            })
            .collect()
    }

    pub(crate) fn dirty(&self, name: &str) -> bool {
        self.surface(name)
            .map(|s| s.borrow().dirty)
            .unwrap_or(false)
    }

    pub(crate) fn mark_dirty(&mut self, name: &str) {
        if let Some(surface) = self.surface(name) {
            surface.borrow_mut().dirty = true;
        }
    }

    pub(crate) fn mark_clean(&mut self, name: &str) -> Option<Surface> {
        let surface = self.surface(name)?.clone();
        surface.borrow_mut().dirty = false;
        Some(surface)
    }

    pub(crate) fn refresh_mipmap(&self, name: &str) {
        if let Some(surface) = self.surface(name) {
            let obj = surface.borrow();
            if obj.needs_mipmap {
                graphics::generate_mipmap(&self.interface, &obj.texture);
            }
        }
    }

    fn assign(&mut self, def: &'static ShadingDef, source: &Texture) {
        let gfx = self.interface.gfx();
        let (width, height) = match gfx.texture_info(source) {
            Ok((x, y, ..)) if x > 0 && y > 0 => (x, y),
            other => {
                log::debug!(
                    "shading {}: skipped source {source}, texture_info {other:?}",
                    def.name
                );
                return;
            }
        };
        let needs_mipmap = def.needs_mipmap;
        let tex = if needs_mipmap {
            graphics::create_repeating_mipmap_fbo_texture(&self.interface, width, height)
        } else {
            graphics::create_fbo_texture(&self.interface, width, height)
        };
        let Some(tex) = tex else {
            log::error!("shading {}: create FBO failed ({width}x{height})", def.name);
            return;
        };
        graphics::blit(&self.interface, source, &tex);
        if needs_mipmap {
            graphics::generate_mipmap(&self.interface, &tex);
        }
        match self
            .interface
            .unsynced_ctrl()
            .set_map_shading_texture(def.bind_type, &tex, def.slot)
        {
            Ok(true) => {}
            other => {
                log::error!(
                    "shading {}: SetMapShadingTexture({}, slot={}) returned {other:?}",
                    def.name,
                    def.bind_type,
                    def.slot
                );
                let _ = gfx.delete_texture(&tex);
                return;
            }
        }
        self.shading.push((
            def.name.to_string(),
            ShadingSlot {
                surface: new_surface(tex, needs_mipmap),
                width,
                height,
            },
        ));
    }
}
