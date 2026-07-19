//! Small helpers over the engine VFS directory listing, shared by the asset
//! grid and by feature-side asset discovery (e.g. texture materials). Not UI.

use spring_native::prelude::NativeInterfaceRef;

pub(crate) fn normalize_extensions(extensions: &[&str]) -> Vec<String> {
    extensions
        .iter()
        .map(|ext| ext.trim_start_matches('.').to_lowercase())
        .collect()
}

/// `DirList`, as Lua's `Path.DirList` uses. Returns leaf names under `dir`,
/// filtered by extension, sorted and de-duplicated.
pub(crate) fn vfs_files(
    interface: &NativeInterfaceRef,
    dir: &str,
    extensions: &[&str],
) -> Vec<String> {
    let extensions = normalize_extensions(extensions);
    let Ok(paths) = interface.vfs().dir_list_names(dir, "*", "", false) else {
        return Vec::new();
    };
    let mut names: Vec<String> = paths
        .iter()
        .filter_map(|path| {
            let name = leaf(path)?;
            let matches = extensions.is_empty()
                || extensions.iter().any(|ext| {
                    name.to_lowercase()
                        .ends_with(&format!(".{}", ext.to_lowercase()))
                });
            matches.then_some(name)
        })
        .collect();
    names.sort();
    names.dedup();
    names
}

/// The last component of a VFS path, with any trailing slash dropped.
pub(crate) fn leaf(path: &str) -> Option<String> {
    let name = path.trim_end_matches('/').rsplit('/').next()?.to_string();
    (!name.is_empty()).then_some(name)
}

/// Join a directory with an entry the engine returned.
///
/// The engine hands back entries already prefixed with the directory, so
/// joining unconditionally yields `bitmaps/bitmaps/foo.bmp` and the texture
/// fails to load. Only join when the entry is a bare name.
pub(crate) fn join_entry(dir: &str, name: &str) -> String {
    if dir.is_empty() || name.contains('/') {
        name.trim_end_matches('/').to_string()
    } else {
        format!("{}/{}", dir.trim_end_matches('/'), name)
    }
}

#[cfg(test)]
mod tests {
    use super::join_entry;

    #[test]
    fn join_entry_does_not_double_prefix_engine_paths() {
        assert_eq!(join_entry("bitmaps", "bitmaps/foo.bmp"), "bitmaps/foo.bmp");
        assert_eq!(join_entry("bitmaps", "foo.bmp"), "bitmaps/foo.bmp");
        assert_eq!(join_entry("", "foo.bmp"), "foo.bmp");
        assert_eq!(join_entry("a", "a/b/"), "a/b");
    }
}
