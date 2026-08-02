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
    let params = sys::GfxTextureParams {
        minFilter: constants::GL_LINEAR,
        magFilter: constants::GL_LINEAR,
        wrapS: constants::GL_CLAMP_TO_EDGE,
        wrapT: constants::GL_CLAMP_TO_EDGE,
        fbo: true,
        ..Default::default()
    };

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
    let params = sys::GfxTextureParams {
        minFilter: constants::GL_LINEAR,
        magFilter: constants::GL_LINEAR,
        wrapS: constants::GL_REPEAT,
        wrapT: constants::GL_REPEAT,
        fbo: true,
        ..Default::default()
    };

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
    let params = sys::GfxTextureParams {
        minFilter: constants::GL_LINEAR_MIPMAP_NEAREST,
        magFilter: constants::GL_LINEAR,
        wrapS: constants::GL_REPEAT,
        wrapT: constants::GL_REPEAT,
        aniso: 16.0,
        fbo: true,
        ..Default::default()
    };

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

/// Write a texture to a PNG (renders it into an FBO, then reads it back).
pub fn save_texture_png(
    interface: &NativeInterfaceRef,
    texture: &Texture,
    width: i32,
    height: i32,
    path: &std::path::Path,
) -> Result<(), String> {
    if let Some(parent) = path.parent() {
        std::fs::create_dir_all(parent)
            .map_err(|err| format!("create {}: {err}", parent.display()))?;
    }
    let path_s = path
        .to_str()
        .ok_or_else(|| format!("non-utf8 path {}", path.display()))?;
    let gfx = interface.gfx();
    let mut err = None;
    gfx.render_to_texture(texture, || {
        match gfx.save_image(0, 0, width, height, path_s, true, false, false, 0) {
            Ok(true) => {}
            Ok(false) => err = Some(format!("save_image returned false for {}", path.display())),
            Err(e) => err = Some(format!("save_image {}: {e:?}", path.display())),
        }
    })
    .map_err(|e| format!("render_to_texture {}: {e:?}", path.display()))?;
    if let Some(err) = err {
        return Err(err);
    }
    Ok(())
}

/// Load a PNG into a new texture.
pub fn load_image_texture(
    interface: &NativeInterfaceRef,
    path: &std::path::Path,
) -> Result<Texture, String> {
    let img = image::open(path).map_err(|err| format!("open {}: {err}", path.display()))?;
    let rgba = img.to_rgba8();
    let (width, height) = rgba.dimensions();
    let Some(texture) = create_fbo_texture(interface, width as i32, height as i32) else {
        return Err(format!("create texture for {} failed", path.display()));
    };
    interface
        .gfx()
        .upload_texture(
            &texture,
            constants::GL_TEXTURE_2D,
            0,
            0,
            0,
            0,
            width as i32,
            height as i32,
            1,
            constants::GL_RGBA,
            constants::GL_UNSIGNED_BYTE,
            rgba.as_raw(),
        )
        .map_err(|err| {
            let _ = interface.gfx().delete_texture(&texture);
            format!("upload {}: {err:?}", path.display())
        })?;
    Ok(texture)
}
