//! Native data-model projection and event binding for a grid's current items.

use spring_native::{
    prelude::{Error, NativeInterfaceRef},
    RmlFieldType, RmlPixels, RmlValueRef,
};

use super::{GridView, FILLERS};
use crate::sbc::panels::field::element_by_id;
use crate::sbc::rml::rows::{Row, Rows};

pub(crate) struct GridRow {
    pub label: String,
    pub image: String,
    pub cell_size: RmlPixels,
    pub has_image: bool,
    pub native_image: bool,
    pub selected: bool,
    pub folder: bool,
    /// A layout-only trailing cell absorbing flex slack.
    pub filler: bool,
}

impl Row for GridRow {
    const FIELDS: &'static [(&'static str, RmlFieldType)] = &[
        ("label", RmlFieldType::String),
        ("image", RmlFieldType::String),
        ("cell_size", RmlFieldType::Pixels),
        ("has_image", RmlFieldType::Bool),
        ("native_image", RmlFieldType::Bool),
        ("selected", RmlFieldType::Bool),
        ("folder", RmlFieldType::Bool),
        ("filler", RmlFieldType::Bool),
    ];

    fn values<'a>(&'a self, out: &mut Vec<RmlValueRef<'a>>) {
        out.push(RmlValueRef::String(&self.label));
        out.push(RmlValueRef::String(&self.image));
        out.push(RmlValueRef::Pixels(self.cell_size));
        out.push(RmlValueRef::Bool(self.has_image));
        out.push(RmlValueRef::Bool(self.native_image));
        out.push(RmlValueRef::Bool(self.selected));
        out.push(RmlValueRef::Bool(self.folder));
        out.push(RmlValueRef::Bool(self.filler));
    }
}

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

        if self.items_dirty {
            let rows = self
                .items
                .iter()
                .map(|item| GridRow {
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
                .chain((0..FILLERS).map(|_| GridRow {
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
            *self.cell_tooltips.borrow_mut() = self
                .items
                .iter()
                .map(|item| {
                    item.tooltip_content.clone().or_else(|| {
                        item.tooltip
                            .as_deref()
                            .map(crate::sbc::panels::tooltip::TooltipContent::text)
                    })
                })
                .collect();
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
            self.rows = Some(Rows::<GridRow>::bind(&model, "items")?);

            let queue = self.clicks.clone();
            Rows::<GridRow>::on_row(&model, "select", move |index, _| {
                queue.borrow_mut().push(index);
            })?;
            let tooltips = self.cell_tooltips.clone();
            let host = self.tooltip.clone();
            let iface = *interface;
            Rows::<GridRow>::on_row(&model, "show_tooltip", move |index, _| {
                let Some(host) = host.borrow().clone() else {
                    return;
                };
                if let Some(Some(content)) = tooltips.borrow().get(index) {
                    let _ = host.show(&iface, content);
                }
            })?;
            let host = self.tooltip.clone();
            Rows::<GridRow>::on_row(&model, "hide_tooltip", move |_, _| {
                if let Some(host) = host.borrow().as_ref() {
                    let _ = host.hide();
                }
            })?;

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
            path.set(navigation.location.clone())?;
        } else {
            log::warn!(
                "navigable grid {} has no typed breadcrumb binding",
                self.container_id
            );
        }
        if let Some(up_disabled) = &self.navigation_up_disabled {
            up_disabled.set(navigation.location.is_empty())?;
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

    fn scaffold_rml(&self) -> String {
        format!(
            concat!(
                r#"<div data-model="{model}" data-for="item : items" data-if="item.visible" class="grid-item" data-class-grid-filler="item.filler" data-class-selected="item.selected" data-class-folder="item.folder" data-style-flex-basis="item.cell_size" data-event-click="select(it_index)" data-event-mouseover="show_tooltip(it_index)" data-event-mouseout="hide_tooltip(it_index)">"#,
                r#"<div class="grid-item-image" data-style-height="item.cell_size"><img data-if="item.has_image &amp;&amp; !item.native_image" data-attr-src="item.image"/><texture data-if="item.has_image &amp;&amp; item.native_image" data-attr-src="item.image"/></div>"#,
                r#"<div class="grid-item-label">{{{{ item.label }}}}</div></div>"#,
            ),
            model = self.model_name(),
        )
    }
}
