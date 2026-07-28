//! A grid of selectable items with an image and a caption.
//!
//! The asset picker, the material picker and the unit/feature pickers are all
//! the same grid with different item sources, so the grid knows nothing about
//! where its items come from.
//!
//! Rebuilding the item markup destroys the elements RmlUi may be dispatching a
//! click to, so a click is queued and acted on a tick later (this is the same
//! use-after-free the Lua port hit).

use std::cell::{Cell, RefCell};
use std::rc::Rc;

use spring_native::{
    prelude::{Error, NativeInterfaceRef},
    RmlDataModel, RmlDataTextRows, RmlDataVariable,
};

use crate::sbc::vfs::{join_entry, leaf, normalize_extensions, vfs_files};

mod render;

/// Enough empty cells to fill out the widest row the panel can hold, so a short
/// last row keeps its items at their natural size.
const FILLERS: usize = 8;

/// One cell.
#[derive(Debug, Clone, PartialEq, Eq)]
pub(crate) struct GridItem {
    /// Stable identity, returned on click. For assets this is the VFS path.
    pub id: String,
    pub caption: String,
    /// VFS path of the cell image, if any.
    pub image: Option<String>,
    /// Directories navigate rather than select.
    pub is_directory: bool,
    /// Hover text, when the cell has more to say than its caption.
    pub tooltip: Option<String>,
    /// RML tooltip content for rich, deliberately-authored tooltips.
    pub tooltip_markup: Option<String>,
}

pub(crate) type ClickQueue = Rc<RefCell<Vec<String>>>;

#[derive(Debug, Clone)]
struct GridNavigation {
    root: String,
    dir: String,
    extensions: Vec<String>,
    up_clicks: Rc<RefCell<u32>>,
    bound: Cell<bool>,
}

pub(crate) struct GridView {
    /// Element id of the container this grid renders into.
    container_id: String,
    items: Vec<GridItem>,
    selected: Option<String>,
    clicks: ClickQueue,
    item_size: u32,
    navigation: Option<GridNavigation>,
    /// The navigation breadcrumb belongs to the surrounding screen's model.
    /// Unlike the grid rows, it exists in markup parsed before this grid has a
    /// chance to create its own item model.
    navigation_path: Option<RmlDataVariable<'static, String>>,
    /// Engine-owned text collection backing the static `data-for` scaffold.
    /// It becomes invalid with its document, so `render` recreates it after a
    /// panel reload.
    rows: Option<RmlDataTextRows<'static>>,
    /// The context that owns `rows`' data model. Unlike document elements,
    /// RmlUi data models survive an editor object being dropped, so an editor
    /// replacement must explicitly release it.
    model_context: Option<u64>,
    bound_document: Option<u64>,
    items_dirty: bool,
}

impl GridView {
    pub(crate) fn new(container_id: &str, item_size: u32) -> Self {
        GridView {
            container_id: container_id.to_string(),
            items: Vec::new(),
            selected: None,
            clicks: Rc::new(RefCell::new(Vec::new())),
            item_size,
            navigation: None,
            navigation_path: None,
            rows: None,
            model_context: None,
            bound_document: None,
            items_dirty: true,
        }
    }

    pub(crate) fn selected(&self) -> Option<&str> {
        self.selected.as_deref()
    }

    pub(crate) fn set_selected(&mut self, id: Option<&str>) {
        self.selected = id.map(str::to_string);
    }

    pub(crate) fn item(&self, id: &str) -> Option<&GridItem> {
        self.items.iter().find(|i| i.id == id)
    }

    /// Clicks queued since the last drain. Handle them outside the RmlUi event
    /// dispatch: acting immediately would free the element being dispatched to.
    pub(crate) fn drain_clicks(&self) -> Vec<String> {
        self.clicks.borrow_mut().drain(..).collect()
    }

    /// Browse the shipped asset directory directly. Brush textures are usable
    /// immediately, and their selected id remains the full VFS path the brush
    /// commands consume.
    pub(crate) fn configure_asset_navigation(&mut self, root_dir: &str, extensions: &[&str]) {
        let root = default_asset_root(root_dir);
        self.navigation = Some(GridNavigation {
            root: root.clone(),
            dir: root,
            extensions: normalize_extensions(extensions),
            up_clicks: Rc::new(RefCell::new(0)),
            bound: Cell::new(false),
        });
    }

    /// Drain inline navigation and selection clicks. A directory changes the
    /// listing and is not returned; files are returned exactly like the old
    /// flat grid API.
    pub(crate) fn drain_asset_clicks(
        &mut self,
        interface: &NativeInterfaceRef,
        document: u64,
    ) -> Result<Vec<String>, Error> {
        if self.navigation.is_none() {
            return Ok(self.drain_clicks());
        }

        let up = self
            .navigation
            .as_ref()
            .map(|navigation| {
                let mut clicks = navigation.up_clicks.borrow_mut();
                let count = *clicks;
                *clicks = 0;
                count
            })
            .unwrap_or_default();
        let mut navigate = false;
        if up > 0 {
            let parent = self.navigation.as_ref().and_then(|navigation| {
                (navigation.dir != navigation.root)
                    .then(|| parent_dir(&navigation.dir))
                    .flatten()
            });
            if let Some(parent) = parent {
                if let Some(navigation) = self.navigation.as_mut() {
                    navigation.dir = parent;
                }
                navigate = true;
            }
        }

        let clicks = self.drain_clicks();
        let mut selected = Vec::new();
        for id in clicks {
            let is_dir = self.item(&id).is_some_and(|item| item.is_directory);
            if is_dir {
                if let Some(navigation) = self.navigation.as_mut() {
                    navigation.dir = id;
                }
                navigate = true;
            } else {
                selected.push(id);
            }
        }

        if navigate {
            self.refresh_navigation(interface, document)?;
        }
        Ok(selected)
    }

    /// Populate the current inline directory. This is public to the owning
    /// editor only because the initial render happens after its RML is bound.
    pub(crate) fn refresh_navigation(
        &mut self,
        interface: &NativeInterfaceRef,
        document: u64,
    ) -> Result<(), Error> {
        let Some((dir, extensions)) = self
            .navigation
            .as_ref()
            .map(|navigation| (navigation.dir.clone(), navigation.extensions.clone()))
        else {
            return Ok(());
        };
        let extensions: Vec<&str> = extensions.iter().map(String::as_str).collect();
        let items = list_asset_directory(interface, &dir, &extensions);
        self.set_items(items);
        self.set_selected(None);
        self.render(interface, document)
    }

    pub(crate) fn container_rml(&self) -> String {
        if self.navigation.is_some() {
            let path = self
                .navigation_path
                .as_ref()
                .map(|_| format!("{{{{ {} }}}}", self.navigation_path_name()))
                .unwrap_or_default();
            return format!(
                r#"<div id="{id}-picker" class="grid-picker">
                    <div class="grid-navigation">
                        <button id="{id}-up" class="dialog-button">Up</button>
                        <span id="{id}-path" class="asset-path">{path}</span>
                    </div>
                    <div id="{id}" class="grid-container"></div>
                </div>"#,
                id = self.container_id,
            );
        }
        format!(
            r#"<div id="{}" class="grid-container"></div>"#,
            self.container_id
        )
    }

    pub(crate) fn set_items(&mut self, items: Vec<GridItem>) {
        self.items = items;
        self.items_dirty = true;
    }

    /// Bind the breadcrumb before its containing markup is parsed. The item
    /// rows intentionally keep their own short-lived model because their
    /// scaffold is inserted only after the grid knows its document context.
    pub(crate) fn prepare_data_model(
        &mut self,
        model: &RmlDataModel<'static>,
    ) -> Result<(), Error> {
        let Some(navigation) = &self.navigation else {
            return Ok(());
        };
        self.navigation_path =
            Some(model.bind(&self.navigation_path_name(), navigation.dir.clone())?);
        Ok(())
    }

    /// Drop document-owned bindings after its panel has been rebuilt.
    pub(crate) fn forget_bindings(&mut self) {
        self.navigation_path = None;
        self.rows = None;
        self.model_context = None;
        self.bound_document = None;
        self.items_dirty = true;
        if let Some(navigation) = &self.navigation {
            navigation.bound.set(false);
        }
    }

    /// Release the context-owned model before this grid's editor is dropped.
    pub(crate) fn release_bindings(&mut self, interface: &NativeInterfaceRef) -> Result<(), Error> {
        if let Some(context) = self.model_context {
            interface
                .rml_ui()
                .remove_data_model(context, &self.model_name())?;
        }
        self.forget_bindings();
        Ok(())
    }

    fn navigation_path_name(&self) -> String {
        format!("{}_path", self.model_name())
    }
}

/// VFS listing for the asset picker: directories first, then files, both sorted.
/// Where SpringBoard's asset packs live (`SB.DIRS.ASSETS`).
const ASSETS_DIR: &str = "springboard/assets";
const DEFAULT_ASSET_PACK: &str = "core";

/// Extensions the grid can render as a thumbnail; every other file (archives,
/// Lua, ...) shows a caption-only cell so RmlUi never tries to load it.
const IMAGE_EXTS: &[&str] = &[
    "png", "jpg", "jpeg", "bmp", "tga", "dds", "tif", "tiff", "gif",
];

/// One level of the assets tree, as `AssetView` walks it.
///
/// At the top there is no directory to list: the entries are the asset *packs*
/// (the subfolders of `springboard/assets/`). Inside a pack, the field's
/// `root_dir` is spliced in -- `assets/<pack>/<root_dir><rest>` -- and what comes
/// back is reported as an asset path (`core/rest/file.png`), which is what the
/// project stores and what the field commits.
pub(crate) fn list_asset_tree(
    interface: &NativeInterfaceRef,
    root_dir: &str,
    dir: &str,
    extensions: &[&str],
) -> Vec<GridItem> {
    // A `vfs:` root browses that VFS directory directly instead of the asset
    // packs — engine-owned content (water's `bitmaps/`) lives outside any pack.
    if let Some(vfs_root) = root_dir.strip_prefix("vfs:") {
        let real = if dir.is_empty() { vfs_root } else { dir };
        return list_assets(interface, real.trim_end_matches('/'), extensions);
    }

    if dir.is_empty() {
        return vfs_sub_dirs(interface, ASSETS_DIR)
            .into_iter()
            .map(|name| GridItem {
                id: format!("{name}/"),
                caption: name,
                image: None,
                is_directory: true,
                tooltip: None,
                tooltip_markup: None,
            })
            .collect();
    }

    // `core/` or `core/sub/dir/` -> the pack, then the rest.
    let (pack, rest) = dir.split_once('/').unwrap_or((dir, ""));
    let real = format!(
        "{ASSETS_DIR}/{pack}/{root}{rest}",
        root = root_dir.trim_start_matches('/'),
    );

    let mut items: Vec<GridItem> = vfs_sub_dirs(interface, &real)
        .into_iter()
        .map(|name| GridItem {
            id: format!("{}{name}/", ensure_slash(dir)),
            caption: name,
            image: None,
            is_directory: true,
            tooltip: None,
            tooltip_markup: None,
        })
        .collect();

    for name in vfs_files(interface, &real, extensions) {
        let asset_path = format!("{}{name}", ensure_slash(dir));
        items.push(GridItem {
            // The cell shows the texture itself, as the Lua asset view does. The
            // *id* stays the asset path (what the field commits); the image is the
            // real VFS path, which is the only thing RmlUi can load.
            image: Some(format!("{real}/{name}")),
            id: asset_path,
            caption: name,
            is_directory: false,
            tooltip: None,
            tooltip_markup: None,
        });
    }
    items
}

pub(crate) fn list_assets(
    interface: &NativeInterfaceRef,
    dir: &str,
    extensions: &[&str],
) -> Vec<GridItem> {
    list_entries(interface, dir, extensions, false)
}

/// Like [`list_assets`], but also lists sub-directories as browsable folder
/// cells. Only the Open/Load dialog wants that: a project is an `.sdd` folder,
/// invisible to the engine's file-only `ListDir`. Texture pickers stay
/// file-only, or engine dirs (`bitmaps/`) would bury the textures under dozens
/// of unrelated sub-folders.
pub(crate) fn list_entries_with_dirs(
    interface: &NativeInterfaceRef,
    dir: &str,
    extensions: &[&str],
) -> Vec<GridItem> {
    list_entries(interface, dir, extensions, true)
}

/// The parent of a VFS directory, or None at the root.
pub(crate) fn parent_dir(dir: &str) -> Option<String> {
    let trimmed = dir.trim_end_matches('/');
    if trimmed.is_empty() {
        return None;
    }
    match trimmed.rsplit_once('/') {
        Some((parent, _)) => Some(parent.to_string()),
        None => Some(String::new()),
    }
}

fn list_entries(
    interface: &NativeInterfaceRef,
    dir: &str,
    extensions: &[&str],
    include_dirs: bool,
) -> Vec<GridItem> {
    let extensions = normalize_extensions(extensions);
    // Directories must come from SubDirs, not the entry listing: the engine's
    // ListDir only ever returns files (it never fills its directory list), so a
    // project -- an `.sdd` folder in the write dir -- is invisible to a plain
    // entry listing and Load comes back empty. SubDirs defaults to VFS.RAW_FIRST,
    // which sees the write dir, exactly as Lua's `Path.SubDirs` does.
    let mut dirs: Vec<GridItem> = if include_dirs {
        vfs_sub_dirs(interface, dir.trim_end_matches('/'))
            .into_iter()
            .map(|name| {
                let path = join_entry(dir, &name);
                // A project folder carries a map thumbnail saved on its last
                // save; show it so projects are recognisable in the Open dialog.
                // Other directories simply have no such file.
                let thumb = format!("{path}/sb_project_files/screenshot.jpg");
                let image = interface
                    .vfs()
                    .file_exists(&thumb)
                    .unwrap_or(false)
                    .then_some(thumb);
                GridItem {
                    id: path,
                    caption: name,
                    image,
                    is_directory: true,
                    tooltip: None,
                    tooltip_markup: None,
                }
            })
            .collect()
    } else {
        Vec::new()
    };

    let mut files = Vec::new();
    if let Ok(entries) = interface.vfs().list_entries(dir, "*", "", false) {
        for entry in entries {
            if entry.is_directory || entry.name.is_empty() {
                continue;
            }
            let path = join_entry(dir, &entry.name);
            let caption = path.rsplit('/').next().unwrap_or(&path).to_string();
            let lower = caption.to_lowercase();
            let matches = extensions.is_empty()
                || extensions
                    .iter()
                    .any(|ext| lower.ends_with(&format!(".{}", ext.to_lowercase())));
            if matches {
                // Only actual images become thumbnails; giving an archive or Lua
                // file an `<img>`/`<texture>` src makes RmlUi try to load it and
                // log `[BMP::Load] invalid bitmap`.
                let is_image = IMAGE_EXTS
                    .iter()
                    .any(|ext| lower.ends_with(&format!(".{ext}")));
                files.push(GridItem {
                    image: is_image.then(|| path.clone()),
                    id: path,
                    caption,
                    is_directory: false,
                    tooltip: None,
                    tooltip_markup: None,
                });
            }
        }
    }

    dirs.sort_by(|a, b| a.caption.cmp(&b.caption));
    files.sort_by(|a, b| a.caption.cmp(&b.caption));
    dirs.extend(files);
    dirs
}

fn default_asset_root(root_dir: &str) -> String {
    format!(
        "{ASSETS_DIR}/{DEFAULT_ASSET_PACK}/{}",
        root_dir.trim_matches('/')
    )
}

/// One directory in the default asset pack, with full VFS paths as item ids.
///
/// `Vfs::list_dir` is intentionally broad and starts at mounted archive roots;
/// the direct `sub_dirs`/`dir_list_names` calls below preserve the requested
/// nested directory instead.
fn list_asset_directory(
    interface: &NativeInterfaceRef,
    dir: &str,
    extensions: &[&str],
) -> Vec<GridItem> {
    let dir = dir.trim_end_matches('/');
    let mut items: Vec<GridItem> = vfs_sub_dirs(interface, dir)
        .into_iter()
        .map(|name| GridItem {
            id: format!("{dir}/{name}"),
            caption: name,
            image: None,
            is_directory: true,
            tooltip: None,
            tooltip_markup: None,
        })
        .collect();
    items.extend(
        vfs_files(interface, dir, extensions)
            .into_iter()
            .map(|name| {
                let path = format!("{dir}/{name}");
                GridItem {
                    id: path.clone(),
                    caption: name,
                    image: Some(path),
                    is_directory: false,
                    tooltip: None,
                    tooltip_markup: None,
                }
            }),
    );
    items
}

fn ensure_slash(dir: &str) -> String {
    if dir.is_empty() || dir.ends_with('/') {
        dir.to_string()
    } else {
        format!("{dir}/")
    }
}

/// Subdirectory names directly under `dir`. The VFS's own `SubDirs`, as Lua's
/// `Path.SubDirs` uses.
fn vfs_sub_dirs(interface: &NativeInterfaceRef, dir: &str) -> Vec<String> {
    let Ok(paths) = interface.vfs().sub_dirs(dir, "*", "", false) else {
        return Vec::new();
    };
    let mut names: Vec<String> = paths.iter().filter_map(|path| leaf(path)).collect();
    names.sort();
    names.dedup();
    names
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parent_dir_walks_up_and_stops_at_the_root() {
        assert_eq!(parent_dir("a/b/c"), Some("a/b".to_string()));
        assert_eq!(parent_dir("a/b/"), Some("a".to_string()));
        assert_eq!(parent_dir("a"), Some(String::new()));
        assert_eq!(parent_dir(""), None);
        assert_eq!(parent_dir("/"), None);
    }

    #[test]
    fn inline_asset_navigation_uses_the_default_pack_vfs_root() {
        assert_eq!(
            default_asset_root("brush_patterns/terrain/"),
            "springboard/assets/core/brush_patterns/terrain"
        );
    }
}
