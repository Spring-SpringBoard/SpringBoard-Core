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

use spring_native::prelude::{Error, NativeInterfaceRef};

use crate::sbc::panels::field::{bind_tooltip, bind_tooltip_markup, element_by_id, escape_rml};

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
            return format!(
                r#"<div id="{id}-picker" class="grid-picker">
                    <div class="grid-navigation">
                        <button id="{id}-up" class="dialog-button">Up</button>
                        <span id="{id}-path" class="asset-path"></span>
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
    }

    /// Render the items and bind a click listener to each cell.
    pub(crate) fn render(
        &self,
        interface: &NativeInterfaceRef,
        document: u64,
    ) -> Result<(), Error> {
        let Some(container) = element_by_id(interface, document, &self.container_id) else {
            return Ok(());
        };
        let rml = interface.rml_ui();

        if let Some(navigation) = self.navigation.as_ref() {
            if let Some(path) =
                element_by_id(interface, document, &format!("{}-path", self.container_id))
            {
                rml.element_set_inner_rml(path, &escape_rml(&navigation.dir))?;
            }
            if let Some(up) =
                element_by_id(interface, document, &format!("{}-up", self.container_id))
            {
                rml.element_set_class(up, "disabled", navigation.dir == navigation.root)?;
            }
            if !navigation.bound.get() {
                if let Some(up) =
                    element_by_id(interface, document, &format!("{}-up", self.container_id))
                {
                    let clicks = navigation.up_clicks.clone();
                    rml.element_add_event_listener(up, "click", false, move || {
                        *clicks.borrow_mut() += 1;
                    })?;
                }
                navigation.bound.set(true);
            }
        }

        let mut html = String::new();
        for (index, item) in self.items.iter().enumerate() {
            let selected = if Some(item.id.as_str()) == self.selected() {
                " selected"
            } else {
                ""
            };
            let folder = if item.is_directory { " folder" } else { "" };
            // The cell grows past `item_size` to share out whatever the row has
            // left over, so the grid has no dead column down its right edge. The
            // image inside keeps its square shape (see the RCSS), so a wider cell
            // just means more margin around the model, not a stretched one.
            html.push_str(&format!(
                r#"<div id="{cid}-{index}" class="grid-item{selected}{folder}" style="flex-basis: {size}px;">"#,
                cid = self.container_id,
                size = self.item_size,
            ));
            html.push_str(&format!(
                r#"<div class="grid-item-image" style="height: {size}px;">"#,
                size = self.item_size,
            ));
            if let Some(image) = &item.image {
                // Engine textures (`!nativeN` RTT thumbnails, `%`/`#`/`$` names)
                // resolve through RmlUi's `<texture>` element; plain file paths
                // are `<img>`.
                // Sized in px rather than as a percentage of the cell: the cell
                // stretches to fill its row, and a percentage would stretch the
                // image with it.
                let square = format!(
                    r#"style="width: {size}px; height: {size}px;""#,
                    size = self.item_size
                );
                if image.starts_with(['!', '%', '#', '$']) {
                    html.push_str(&format!(r#"<texture src="{image}" {square}/>"#));
                } else {
                    html.push_str(&format!(r#"<img src="{image}" {square}/>"#));
                }
            }
            html.push_str("</div>");
            html.push_str(&format!(
                r#"<div class="grid-item-label">{}</div></div>"#,
                escape_rml(&item.caption),
            ));
        }
        // Without these, the items on a short last row would grow to swallow the
        // whole row -- one lone result would be a cell the width of the grid. The
        // fillers take that slack instead, and being empty and flat they cost a
        // row of nothing. Any that don't fit wrap away invisibly.
        for _ in 0..FILLERS {
            html.push_str(&format!(
                r#"<div class="grid-filler" style="flex-basis: {size}px;"></div>"#,
                size = self.item_size,
            ));
        }
        rml.element_set_inner_rml(container, &html)?;

        for (index, item) in self.items.iter().enumerate() {
            let id = format!("{}-{}", self.container_id, index);
            let Some(cell) = element_by_id(interface, document, &id) else {
                continue;
            };
            if let Some(tooltip) = &item.tooltip_markup {
                bind_tooltip_markup(interface, document, cell, tooltip)?;
            } else if let Some(tooltip) = &item.tooltip {
                bind_tooltip(interface, document, cell, tooltip)?;
            }
            let queue = self.clicks.clone();
            let item_id = item.id.clone();
            rml.element_add_event_listener(cell, "click", false, move || {
                queue.borrow_mut().push(item_id.clone());
            })?;
        }
        Ok(())
    }
}

/// VFS listing for the asset picker: directories first, then files, both sorted.
/// Where SpringBoard's asset packs live (`SB.DIRS.ASSETS`).
const ASSETS_DIR: &str = "springboard/assets";
const DEFAULT_ASSET_PACK: &str = "core";

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

/// File names directly under `dir`, matching one of `extensions`. The VFS's own
/// Extensions are matched as `.ext`, so a field may write either `png` or `.png`
/// and both listers agree. They disagreed before, and a dotted list silently
/// matched nothing.
fn normalize_extensions(extensions: &[&str]) -> Vec<String> {
    extensions
        .iter()
        .map(|ext| ext.trim_start_matches('.').to_lowercase())
        .collect()
}

/// `DirList`, as Lua's `Path.DirList` uses.
fn vfs_files(interface: &NativeInterfaceRef, dir: &str, extensions: &[&str]) -> Vec<String> {
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
fn leaf(path: &str) -> Option<String> {
    let name = path.trim_end_matches('/').rsplit('/').next()?.to_string();
    (!name.is_empty()).then_some(name)
}

pub(crate) fn list_assets(
    interface: &NativeInterfaceRef,
    dir: &str,
    extensions: &[&str],
) -> Vec<GridItem> {
    let extensions = normalize_extensions(extensions);
    // Non-recursive listing across every VFS mode, as Lua's Path.DirList does.
    let Ok(entries) = interface.vfs().list_dir(dir, "*", "", false) else {
        return Vec::new();
    };

    let mut dirs = Vec::new();
    let mut files = Vec::new();
    for entry in entries {
        let name = unsafe { std::ffi::CStr::from_ptr(entry.name) }
            .to_string_lossy()
            .into_owned();
        if name.is_empty() {
            continue;
        }
        let path = join_entry(dir, &name);
        let caption = path.rsplit('/').next().unwrap_or(&path).to_string();

        if entry.isDirectory {
            dirs.push(GridItem {
                id: path,
                caption,
                image: None,
                is_directory: true,
                tooltip: None,
                tooltip_markup: None,
            });
        } else {
            let matches = extensions.is_empty()
                || extensions.iter().any(|ext| {
                    caption
                        .to_lowercase()
                        .ends_with(&format!(".{}", ext.to_lowercase()))
                });
            if matches {
                files.push(GridItem {
                    image: Some(path.clone()),
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

/// Join a directory with an entry the engine returned.
///
/// The engine hands back entries already prefixed with the directory, so
/// joining unconditionally yields `bitmaps/bitmaps/foo.bmp` and the texture
/// fails to load. Only join when the entry is a bare name.
fn join_entry(dir: &str, name: &str) -> String {
    if dir.is_empty() || name.contains('/') {
        name.trim_end_matches('/').to_string()
    } else {
        format!("{}/{}", dir.trim_end_matches('/'), name)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn entry_paths_are_not_doubled() {
        // The engine hands back `bitmaps/foo.bmp` inside `bitmaps`.
        assert_eq!(join_entry("bitmaps", "bitmaps/foo.bmp"), "bitmaps/foo.bmp");
        assert_eq!(join_entry("bitmaps", "foo.bmp"), "bitmaps/foo.bmp");
        assert_eq!(join_entry("", "foo.bmp"), "foo.bmp");
        assert_eq!(join_entry("a", "a/b/"), "a/b");
    }

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
