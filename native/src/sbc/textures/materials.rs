//! Brush-material discovery: grouping the files under `brush_textures/` into
//! materials by channel suffix. Owned by the textures feature; the editor UI
//! consumes it.

use std::collections::BTreeMap;

use spring_native::prelude::NativeInterfaceRef;

use crate::sbc::vfs::{join_entry, vfs_files};

/// A material's channels, as `TextureManager.materialTextures` defines them: one
/// texture per channel, found by suffix next to the diffuse.
///
/// `normal` is a channel of every material but has no enable toggle, exactly as
/// Lua skips it when it builds the checkboxes.
pub(crate) const CHANNELS: &[(&str, &str, bool)] = &[
    ("diffuse", "Diffuse", true),
    ("specular", "Specular", true),
    ("normal", "Normal", false),
    ("emission", "Emission", true),
    ("refl", "Refl", true),
];

const IMAGE_EXTS: &[&str] = &[".png", ".jpg", ".tga", ".dds", ".bmp"];

const ROOT: &str = "springboard/assets/core/brush_textures";

/// One material: its name, and the channel textures that exist for it.
#[derive(Clone)]
pub(crate) struct Material {
    /// The bare material name (`dirt1`), which is what the picker shows.
    pub(crate) name: String,
    pub(crate) channels: BTreeMap<String, String>,
}

/// Group the files under `brush_textures/` into materials. A material exists if
/// it has a diffuse; the other channels are optional, which is why the picker
/// shows which ones were found.
pub(crate) fn list_materials(interface: &NativeInterfaceRef) -> Vec<Material> {
    let mut found: BTreeMap<String, BTreeMap<String, String>> = BTreeMap::new();

    for name in vfs_files(interface, ROOT, IMAGE_EXTS) {
        let path = join_entry(ROOT, &name);
        if let Some((material, channel)) = material_of(&path) {
            found
                .entry(material)
                .or_default()
                .insert(channel.to_string(), path);
        }
    }

    found
        .into_iter()
        .filter(|(_, channels)| channels.contains_key("diffuse"))
        .map(|(name, channels)| Material { name, channels })
        .collect()
}

/// The material a texture belongs to: its file name with the channel suffix
/// stripped, and without the directory. `.../brush_textures/dirt1_diffuse.png`
/// is the `diffuse` of `dirt1`.
fn material_of(path: &str) -> Option<(String, &'static str)> {
    let file = path.rsplit('/').next()?;
    let stem = file.rsplit_once('.').map(|(s, _)| s).unwrap_or(file);
    for (channel, _, _) in CHANNELS {
        if let Some(base) = stem.strip_suffix(&format!("_{channel}")) {
            return Some((base.to_string(), channel));
        }
    }
    None
}

#[cfg(test)]
mod tests {
    use super::*;

    /// The VFS hands back full paths, so the material's name is the file's, not
    /// the path's -- every material was captioned "springboard" until it was.
    #[test]
    fn a_material_is_named_after_its_file_not_its_path() {
        let (name, channel) =
            material_of("springboard/assets/core/brush_textures/dirt1_diffuse.png").unwrap();
        assert_eq!(name, "dirt1");
        assert_eq!(channel, "diffuse");

        let (name, channel) =
            material_of("springboard/assets/core/brush_textures/cement_normal.png").unwrap();
        assert_eq!(name, "cement");
        assert_eq!(channel, "normal");
    }

    #[test]
    fn a_texture_with_no_channel_suffix_belongs_to_no_material() {
        assert!(material_of("brush_textures/readme.png").is_none());
    }
}
