//! Native data-model projection and event binding for a grid's current items.

use spring_native::{
    prelude::{Error, NativeInterfaceRef},
    RmlGridRow, RmlPixels,
};

use super::{GridItem, GridView, FILLERS};
use crate::sbc::panels::field::element_by_id;

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
                .map(|item| RmlGridRow {
                    label: item.caption.clone(),
                    image: item.image.clone().unwrap_or_default(),
                    cell_size: RmlPixels(self.item_size as f32),
                    has_image: item.image.is_some(),
                    native_image: item
                        .image
                        .as_deref()
                        .is_some_and(|path| path.starts_with(['!', '%', '#', '$'])),
                    selected: Some(item.id.as_str()) == self.selected(),
                    folder: item.is_directory,
                    filler: false,
                })
                .chain((0..FILLERS).map(|_| RmlGridRow {
                    label: String::new(),
                    image: String::new(),
                    cell_size: RmlPixels(self.item_size as f32),
                    has_image: false,
                    native_image: false,
                    selected: false,
                    folder: false,
                    filler: true,
                }))
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
            self.sync_item(interface, document, cell, item, items_changed)?;
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
            self.rows = Some(model.bind_grid_rows("items")?);
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
        if let Some(path) = &self.navigation_path {
            path.set(navigation.dir.clone())?;
        } else {
            log::warn!(
                "navigable grid {} has no typed breadcrumb binding",
                self.container_id
            );
        }
        if let Some(up_disabled) = &self.navigation_up_disabled {
            up_disabled.set(navigation.dir == navigation.root)?;
        }
        if let Some(up) = element_by_id(interface, document, &format!("{}-up", self.container_id)) {
            if !navigation.bound.get() {
                let clicks = navigation.up_clicks.clone();
                interface
                    .rml_ui()
                    .element_add_event_listener(up, "click", false, move || {
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
        _document: u64,
        cell: u64,
        item: &GridItem,
        bind_interactions: bool,
    ) -> Result<(), Error> {
        if bind_interactions {
            if let Some(host) = &self.tooltip {
                if let Some(tooltip) = &item.tooltip_content {
                    host.bind_to(interface, cell, tooltip.clone())?;
                } else if let Some(tooltip) = &item.tooltip {
                    host.bind_to(
                        interface,
                        cell,
                        crate::sbc::panels::tooltip::TooltipContent::text(tooltip),
                    )?;
                }
            }
            let queue = self.clicks.clone();
            let item_id = item.id.clone();
            interface
                .rml_ui()
                .element_add_event_listener(cell, "click", false, move || {
                    queue.borrow_mut().push(item_id.clone());
                })?;
        }
        Ok(())
    }

    fn scaffold_rml(&self) -> String {
        format!(
            concat!(
                r#"<div data-model="{model}" data-for="item : items" data-if="item.visible" class="grid-item" data-class-grid-filler="item.filler" data-class-selected="item.selected" data-class-folder="item.folder" data-style-flex-basis="item.cell_size">"#,
                r#"<div class="grid-item-image" data-style-height="item.cell_size"><img data-if="item.has_image &amp;&amp; !item.native_image" data-attr-src="item.image"/><texture data-if="item.has_image &amp;&amp; item.native_image" data-attr-src="item.image"/></div>"#,
                r#"<div class="grid-item-label">{{{{ item.label }}}}</div></div>"#,
            ),
            model = self.model_name(),
        )
    }
}
