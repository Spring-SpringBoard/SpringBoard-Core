//! Shared body of the Objects tab's Units and Features views.
//!
//! Both are a search box over a grid of definitions. Selecting one is what the
//! map click then places, so selection is local state and dispatches nothing.
//!
//! Thumbnails are missing: Lua renders each def to a Lua dynamic texture and
//! shows it with `<texture src="!N">`. The native interface has no equivalent
//! render-to-texture binding, so the cells are captions only until one exists.
//! Build pictures are deliberately *not* used as a substitute — many games have
//! none.

use spring_native::prelude::{Error, NativeInterfaceRef};

use crate::sbc::panels::field::{escape_rml, ChangeQueue, InteractionQueue};
use crate::sbc::panels::grid::{GridItem, GridView};
use crate::sbc::rml::element_by_id;

/// Which definitions a view lists.
#[derive(Clone, Copy, PartialEq, Eq)]
pub(crate) enum DefKind {
    Unit,
    Feature,
}

pub(crate) struct ObjectDefsView {
    kind: DefKind,
    grid: GridView,
    /// Every definition, unfiltered; the grid holds the filtered subset.
    all: Vec<GridItem>,
    search: String,
    search_element: Option<u64>,
    loaded: bool,
    /// The search box fired `change`; re-filter on the next tick, where the
    /// document handle is available and RmlUi is not mid-dispatch.
    search_dirty: bool,
    /// A definition was just clicked; the view turns this into a placement state.
    selection_change: Option<String>,
}

impl ObjectDefsView {
    pub(crate) fn new(kind: DefKind) -> Self {
        ObjectDefsView {
            kind,
            grid: GridView::new("object-defs-grid", 64),
            all: Vec::new(),
            search: String::new(),
            search_element: None,
            loaded: false,
            search_dirty: false,
            selection_change: None,
        }
    }

    pub(crate) fn mark_search_dirty(&mut self) {
        self.search_dirty = true;
    }

    pub(crate) fn selected(&self) -> Option<&str> {
        self.grid.selected()
    }

    /// The definition picked since this was last called.
    pub(crate) fn take_selection_change(&mut self) -> Option<String> {
        self.selection_change.take()
    }

    pub(crate) fn generate_rml(&self) -> String {
        format!(
            concat!(
                r#"<div class="field-row">"#,
                r#"<span class="field-label">Search:</span>"#,
                r#"<input type="text" id="object-defs-search" class="field-input"/>"#,
                r#"</div>{grid}"#,
            ),
            grid = self.grid.container_rml(),
        )
    }

    pub(crate) fn bind(
        &mut self,
        interface: &NativeInterfaceRef,
        document: u64,
        changes: &ChangeQueue,
        _interactions: &InteractionQueue,
    ) -> Result<(), Error> {
        self.search_element = element_by_id(interface, document, "object-defs-search");
        if let Some(element) = self.search_element {
            let queue = changes.clone();
            interface
                .rml_ui()
                .element_add_event_listener(element, "change", false, move || {
                    queue
                        .borrow_mut()
                        .push(crate::sbc::panels::field::CommitRequest {
                            field: "search".to_string(),
                            from_blur: false,
                        });
                })?;
        }
        Ok(())
    }

    /// Load the definitions once, then render whatever the search matches.
    pub(crate) fn tick(
        &mut self,
        interface: &NativeInterfaceRef,
        document: u64,
    ) -> Result<(), Error> {
        if !self.loaded {
            self.all = match self.kind {
                DefKind::Unit => unit_defs(interface),
                DefKind::Feature => feature_defs(interface),
            };
            self.loaded = true;
            self.apply_filter(interface, document)?;
        }

        if self.search_dirty {
            self.search_dirty = false;
            if let Some(element) = self.search_element {
                if let Ok((Some(value), true)) =
                    interface.rml_ui().element_get_attribute(element, "value")
                {
                    self.search = value.to_lowercase();
                }
            }
            self.apply_filter(interface, document)?;
        }

        for id in self.grid.drain_clicks() {
            self.grid.set_selected(Some(&id));
            self.selection_change = Some(id);
            self.grid.render(interface, document)?;
        }
        Ok(())
    }

    fn apply_filter(&mut self, interface: &NativeInterfaceRef, document: u64) -> Result<(), Error> {
        let matches: Vec<GridItem> = self
            .all
            .iter()
            .filter(|item| {
                self.search.is_empty()
                    || item.caption.to_lowercase().contains(&self.search)
                    || item.id.to_lowercase().contains(&self.search)
            })
            .cloned()
            .collect();
        self.grid.set_items(matches);
        self.grid.render(interface, document)
    }
}

fn unit_defs(interface: &NativeInterfaceRef) -> Vec<GridItem> {
    let defs = interface.unit_defs();
    let count = defs.get_unit_def_count().unwrap_or(0);
    let mut items = Vec::new();
    for id in 1..=count as i32 {
        let Ok(Some(name)) = defs.get_unit_def_name(id) else {
            continue;
        };
        let caption = defs
            .get_unit_def_human_name(id)
            .ok()
            .flatten()
            .unwrap_or_else(|| name.clone());
        items.push(GridItem {
            id: name,
            caption: escape_rml(&caption),
            image: None,
            is_directory: false,
        });
    }
    items.sort_by(|a, b| a.caption.cmp(&b.caption));
    items
}

fn feature_defs(interface: &NativeInterfaceRef) -> Vec<GridItem> {
    let defs = interface.feature_defs();
    let Ok(ids) = defs.get_feature_def_ids() else {
        return Vec::new();
    };
    let mut items = Vec::new();
    for id in ids {
        let Ok((info, true)) = defs.get_feature_def_by_id(id) else {
            continue;
        };
        let name = unsafe { std::ffi::CStr::from_ptr(info.name) }
            .to_string_lossy()
            .into_owned();
        if name.is_empty() {
            continue;
        }
        items.push(GridItem {
            id: name.clone(),
            caption: escape_rml(&name),
            image: None,
            is_directory: false,
        });
    }
    items.sort_by(|a, b| a.caption.cmp(&b.caption));
    items
}
