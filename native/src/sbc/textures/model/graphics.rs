//! GL helpers shared by texture painting.

use spring_native::prelude::{constants, sys, NativeInterfaceRef};

/// An engine texture handle (the name the engine gives a created texture).
/// Derefs to `&str` so it passes straight to the `gfx`/`vfs` calls; (de)serializes
/// transparently as a string, so texture names cross the JSON boundary as
/// `Texture` directly.
#[derive(Clone, Debug, Default, PartialEq, Eq, Hash, serde::Serialize, serde::Deserialize)]
pub struct Texture(String);

impl std::ops::Deref for Texture {
    type Target = str;
    fn deref(&self) -> &str {
        &self.0
    }
}

impl From<String> for Texture {
    fn from(name: String) -> Self {
        Texture(name)
    }
}

impl std::fmt::Display for Texture {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.write_str(&self.0)
    }
}

/// Create an FBO-backed RGBA texture with linear filtering and clamp-to-edge
/// wrapping. `None` if creation failed.
pub fn create_fbo_texture(
    interface: &NativeInterfaceRef,
    width: i32,
    height: i32,
) -> Option<Texture> {
    let mut params: sys::GfxTextureParams = unsafe { std::mem::zeroed() };
    params.minFilter = constants::GL_LINEAR;
    params.magFilter = constants::GL_LINEAR;
    params.wrapS = constants::GL_CLAMP_TO_EDGE;
    params.wrapT = constants::GL_CLAMP_TO_EDGE;
    params.fbo = true;

    interface
        .gfx()
        .create_texture(width, height, 1, params)
        .ok()
        .flatten()
        .map(Texture)
}

/// Create an FBO texture suitable for tiled material/brush sampling.
pub fn create_repeating_fbo_texture(
    interface: &NativeInterfaceRef,
    width: i32,
    height: i32,
) -> Option<Texture> {
    let mut params: sys::GfxTextureParams = unsafe { std::mem::zeroed() };
    params.minFilter = constants::GL_LINEAR;
    params.magFilter = constants::GL_LINEAR;
    params.wrapS = constants::GL_REPEAT;
    params.wrapT = constants::GL_REPEAT;
    params.fbo = true;

    interface
        .gfx()
        .create_texture(width, height, 1, params)
        .ok()
        .flatten()
        .map(Texture)
}

pub fn create_repeating_mipmap_fbo_texture(
    interface: &NativeInterfaceRef,
    width: i32,
    height: i32,
) -> Option<Texture> {
    let mut params: sys::GfxTextureParams = unsafe { std::mem::zeroed() };
    params.minFilter = constants::GL_LINEAR_MIPMAP_NEAREST;
    params.magFilter = constants::GL_LINEAR;
    params.wrapS = constants::GL_REPEAT;
    params.wrapT = constants::GL_REPEAT;
    params.aniso = 16.0;
    params.fbo = true;

    interface
        .gfx()
        .create_texture(width, height, 1, params)
        .ok()
        .flatten()
        .map(Texture)
}

pub fn generate_mipmap(interface: &NativeInterfaceRef, texture: &str) {
    if let Err(err) = interface.gfx().generate_mipmap(texture) {
        log::error!("generate_mipmap({texture}) failed: {err:?}");
    }
}

/// Copy `src` onto FBO-backed `dst`.
pub fn blit(interface: &NativeInterfaceRef, src: &Texture, dst: &Texture) {
    let gfx = interface.gfx();
    let _ = gfx.blending(false);
    let _ = gfx.use_shader(0);
    let _ = gfx.color(1.0, 1.0, 1.0, 1.0);
    let _ = gfx.bind_texture(src, 0, true);
    let _ = gfx.render_to_texture(dst, || {
        let _ = gfx.tex_rect(-1.0, -1.0, 1.0, 1.0, 0.0, 0.0, 1.0, 1.0);
    });
    let _ = gfx.bind_texture(src, 0, false);
}

/// Create an FBO copy of `src` with the same dimensions.
pub fn copy_texture(interface: &NativeInterfaceRef, src: &Texture) -> Option<Texture> {
    let (w, h, ..) = interface.gfx().texture_info(src).ok()?;
    if w <= 0 || h <= 0 {
        return None;
    }
    let dst = create_fbo_texture(interface, w, h)?;
    blit(interface, src, &dst);
    Some(dst)
}
