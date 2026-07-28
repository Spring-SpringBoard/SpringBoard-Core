//! Native data-model projection and event binding for a grid's current items.

use spring_native::{
    prelude::{Error, NativeInterfaceRef},
    RmlTextRow,
};

use super::{GridItem, GridView, FILLERS};
use crate::sbc::panels::field::{bind_tooltip, bind_tooltip_markup, element_by_id, escape_rml};

impl GridView {
    pub(super) fn model_name(&self) -> String {
        format!(
            "grid_{}",
            self.container_id
                .chars()
                .map(|ch| if ch.is_ascii_alphanumeric() { ch } else { '_' })
                .collect::<String>()
        )
    }

    pub(crate) fn render(
        &mut self,
        interface: &NativeInterfaceRef,
        document: u64,
    ) -> Result<(), Error> {
        let Some(container) = element_by_id(interface, document, &self.container_id) else {
            return Ok(());
        };
        let rml = interface.rml_ui();
        let (context, context_exists) = rml.document_get_context(document)?;
        if !context_exists {
            return Ok(());
        }

        self.ensure_rows(interface, document, context, container)?;
        self.render_navigation(interface, document)?;

        let items_changed = self.items_dirty;
        if items_changed {
            let rows = self
                .items
                .iter()
                .map(|item| RmlTextRow {
                    text: item.caption.clone(),
                    muted: false,
                })
                .collect::<Vec<_>>();
            if let Some(rows_model) = &self.rows {
                rows_model.set(&rows)?;
            }
            // `data-for` materialises on update. Grid rows have per-cell
            // interactions, so bind only after those real elements exist.
            let _ = rml.context_update(context)?;
        }

        for (index, item) in self.items.iter().enumerate() {
            let (cell, exists) = rml.element_get_child(container, index as i32)?;
            if !exists {
                continue;
            }
            self.sync_item(interface, document, cell, item, index, items_changed)?;
        }
        self.items_dirty = false;
        Ok(())
    }

    fn ensure_rows(
        &mut self,
        interface: &NativeInterfaceRef,
        document: u64,
        context: u64,
        container: u64,
    ) -> Result<(), Error> {
        if self.bound_document != Some(document) {
            let model = interface
                .rml_ui()
                .create_data_model(context, &self.model_name())?;
            self.rows = Some(model.bind_text_rows("items")?);
            self.model_context = Some(context);
            self.bound_document = Some(document);
            self.items_dirty = true;
        }

        let (_, has_child) = interface.rml_ui().element_get_child(container, 0)?;
        if !has_child {
            let rml = interface.rml_ui();
            rml.element_set_inner_rml(container, &self.scaffold_rml())?;
            self.items_dirty = true;
        }
        Ok(())
    }

    fn render_navigation(
        &self,
        interface: &NativeInterfaceRef,
        document: u64,
    ) -> Result<(), Error> {
        let Some(navigation) = self.navigation.as_ref() else {
            return Ok(());
        };
        let rml = interface.rml_ui();
        if let Some(path) = &self.navigation_path {
            path.set(navigation.dir.clone())?;
        } else if let Some(path) =
            element_by_id(interface, document, &format!("{}-path", self.container_id))
        {
            // Grids may also be mounted by legacy callers that do not own a
            // pre-parsed data model yet. Keep that path working while those
            // callers are migrated.
            rml.element_set_inner_rml(path, &escape_rml(&navigation.dir))?;
        }
        if let Some(up) = element_by_id(interface, document, &format!("{}-up", self.container_id)) {
            rml.element_set_class(up, "disabled", navigation.dir == navigation.root)?;
            if !navigation.bound.get() {
                let clicks = navigation.up_clicks.clone();
                rml.element_add_event_listener(up, "click", false, move || {
                    *clicks.borrow_mut() += 1;
                })?;
                navigation.bound.set(true);
            }
        }
        Ok(())
    }

    fn sync_item(
        &self,
        interface: &NativeInterfaceRef,
        document: u64,
        cell: u64,
        item: &GridItem,
        index: usize,
        bind_interactions: bool,
    ) -> Result<(), Error> {
        let rml = interface.rml_ui();
        rml.element_set_attribute(cell, "id", &format!("{}-{index}", self.container_id))?;
        rml.element_set_attribute(cell, "style", &format!("flex-basis: {}px;", self.item_size))?;
        rml.element_set_class(cell, "selected", Some(item.id.as_str()) == self.selected())?;
        rml.element_set_class(cell, "folder", item.is_directory)?;

        let (image_box, has_image_box) = rml.element_get_child(cell, 0)?;
        if has_image_box {
            rml.element_set_attribute(
                image_box,
                "style",
                &format!("height: {}px;", self.item_size),
            )?;
            let (image, has_image) = rml.element_get_child(image_box, 0)?;
            let (texture, has_texture) = rml.element_get_child(image_box, 1)?;
            let is_texture = item
                .image
                .as_deref()
                .is_some_and(|path| path.starts_with(['!', '%', '#', '$']));
            if has_image {
                if let Some(path) = item.image.as_deref().filter(|_| !is_texture) {
                    rml.element_set_attribute(image, "src", path)?;
                    rml.element_set_attribute(
                        image,
                        "style",
                        &format!(
                            "display: block; width: {}px; height: {}px;",
                            self.item_size, self.item_size
                        ),
                    )?;
                } else {
                    // `.grid-item-image img` is more specific than the shared
                    // `.hidden` class. Inline display keeps a stale thumbnail
                    // from a reused data-for row from becoming visible.
                    rml.element_set_attribute(image, "style", "display: none;")?;
                }
            }
            if has_texture {
                if let Some(path) = item.image.as_deref().filter(|_| is_texture) {
                    rml.element_set_attribute(texture, "src", path)?;
                    rml.element_set_attribute(
                        texture,
                        "style",
                        &format!(
                            "display: block; width: {}px; height: {}px;",
                            self.item_size, self.item_size
                        ),
                    )?;
                } else {
                    rml.element_set_attribute(texture, "style", "display: none;")?;
                }
            }
        }

        if bind_interactions {
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

    fn scaffold_rml(&self) -> String {
        let mut rml = format!(
            concat!(
                r#"<div data-model="{model}" data-for="item : items" class="grid-item">"#,
                r#"<div class="grid-item-image"><img class="hidden"/><texture class="hidden"/></div>"#,
                r#"<div class="grid-item-label">{{{{ item.text }}}}</div></div>"#,
            ),
            model = self.model_name(),
        );
        for _ in 0..FILLERS {
            rml.push_str(&format!(
                r#"<div class="grid-filler" style="flex-basis: {}px;"></div>"#,
                self.item_size
            ));
        }
        rml
    }
}
