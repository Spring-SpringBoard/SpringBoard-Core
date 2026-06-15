use spring_native::prelude::NativeInterfaceRef;

use super::super::graphics::{self, Texture};
use super::surface::{new_surface, Surface};

/// A snapshot of one shading texture's current state.
pub(crate) struct ShadingTexture {
    pub texture: Texture,
    pub width: i32,
    pub height: i32,
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
                texture: slot.surface.borrow().texture.clone(),
                width: slot.width,
                height: slot.height,
            })
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
