//! A grid of selectable items with an image and a caption.
//!
//! The asset picker, the material picker and the unit/feature pickers are all
//! the same grid with different item sources, so the grid knows nothing about
//! where its items come from.
//!
//! Rebuilding the item markup destroys the elements RmlUi may be dispatching a
//! click to, so a click is queued and acted on a tick later (this is the same
//! use-after-free the Lua port hit).

use std::cell::RefCell;
use std::rc::Rc;

use spring_native::prelude::{Error, NativeInterfaceRef};

use crate::sbc::panels::field::{element_by_id, escape_rml};

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
}

pub(crate) type ClickQueue = Rc<RefCell<Vec<String>>>;

pub(crate) struct GridView {
    /// Element id of the container this grid renders into.
    container_id: String,
    items: Vec<GridItem>,
    selected: Option<String>,
    clicks: ClickQueue,
    item_size: u32,
}

impl GridView {
    pub(crate) fn new(container_id: &str, item_size: u32) -> Self {
        GridView {
            container_id: container_id.to_string(),
            items: Vec::new(),
            selected: None,
            clicks: Rc::new(RefCell::new(Vec::new())),
            item_size,
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

    pub(crate) fn container_rml(&self) -> String {
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

        let mut html = String::new();
        for (index, item) in self.items.iter().enumerate() {
            let selected = if Some(item.id.as_str()) == self.selected() {
                " selected"
            } else {
                ""
            };
            let folder = if item.is_directory { " folder" } else { "" };
            html.push_str(&format!(
                r#"<div id="{cid}-{index}" class="grid-item{selected}{folder}" style="width: {size}px;">"#,
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
                if image.starts_with(['!', '%', '#', '$']) {
                    html.push_str(&format!(r#"<texture src="{image}"/>"#));
                } else {
                    html.push_str(&format!(r#"<img src="{image}"/>"#));
                }
            }
            html.push_str("</div>");
            html.push_str(&format!(
                r#"<div class="grid-item-label">{}</div></div>"#,
                escape_rml(&item.caption),
            ));
        }
        rml.element_set_inner_rml(container, &html)?;

        for (index, item) in self.items.iter().enumerate() {
            let id = format!("{}-{}", self.container_id, index);
            let Some(cell) = element_by_id(interface, document, &id) else {
                continue;
            };
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
pub(crate) fn list_assets(
    interface: &NativeInterfaceRef,
    dir: &str,
    extensions: &[&str],
) -> Vec<GridItem> {
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
            });
        } else {
            let matches = extensions.is_empty()
                || extensions
                    .iter()
                    .any(|ext| caption.to_lowercase().ends_with(ext));
            if matches {
                files.push(GridItem {
                    image: Some(path.clone()),
                    id: path,
                    caption,
                    is_directory: false,
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
}
