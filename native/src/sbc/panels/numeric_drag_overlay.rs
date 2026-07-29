//! Screen-level presentation for a numeric drag.
//!
//! This deliberately has its own RmlUi context. It is a screen-level plane,
//! independent from the editor and status contexts, just like Chili's global
//! draw.

use spring_native::{
    prelude::{Error, NativeInterfaceRef},
    RmlDataModel, RmlDataVariable, RmlPixels,
};

use crate::sbc::panels::field::NumericDragPresentation;
use crate::sbc::rml;

const CONTEXT: &str = "sbc_numeric_drag_overlay";
const MODEL: &str = "numeric_drag_overlay";
const MARKUP: &str = r#"
<div data-model="numeric_drag_overlay" class="numeric-drag-overlay">
  <div class="numeric-drag-overlay-control" data-style-left="left" data-style-top="top" data-style-width="width" data-style-height="height">
    <div class="numeric-drag-overlay-progress theme-interaction-drag-progress" data-class-hidden="!has_progress" data-style-width="progress_width" data-style-height="progress_height"></div>
    <span class="numeric-drag-overlay-title theme-interaction-drag-text">{{ title }}:</span>
    <span class="numeric-drag-overlay-value theme-interaction-drag-text">{{ value }}</span>
    <div class="numeric-drag-overlay-bound numeric-drag-overlay-bound-min theme-interaction-drag-callout" data-class-hidden="!has_min">{{ min }}</div>
    <div class="numeric-drag-overlay-bound numeric-drag-overlay-bound-max theme-interaction-drag-callout" data-class-hidden="!has_max">{{ max }}</div>
  </div>
</div>"#;
const STYLE: &str = concat!(
    include_str!("../theme/base.rcss"),
    include_str!("../theme/panel/fields.rcss"),
);

#[derive(Default)]
pub(crate) struct NumericDragOverlay {
    context: Option<u64>,
    document: Option<u64>,
    has_min: Option<RmlDataVariable<'static, bool>>,
    has_max: Option<RmlDataVariable<'static, bool>>,
    has_progress: Option<RmlDataVariable<'static, bool>>,
    title: Option<RmlDataVariable<'static, String>>,
    value: Option<RmlDataVariable<'static, String>>,
    min: Option<RmlDataVariable<'static, String>>,
    max: Option<RmlDataVariable<'static, String>>,
    left: Option<RmlDataVariable<'static, RmlPixels>>,
    top: Option<RmlDataVariable<'static, RmlPixels>>,
    width: Option<RmlDataVariable<'static, RmlPixels>>,
    height: Option<RmlDataVariable<'static, RmlPixels>>,
    progress_width: Option<RmlDataVariable<'static, RmlPixels>>,
    progress_height: Option<RmlDataVariable<'static, RmlPixels>>,
}

impl NumericDragOverlay {
    pub(crate) fn show(
        &mut self,
        interface: &NativeInterfaceRef,
        presentation: NumericDragPresentation,
    ) -> Result<(), Error> {
        self.ensure(interface)?;
        let Ok((left, top, width, height)) =
            interface.rml_ui().element_get_rect(presentation.element)
        else {
            return Ok(());
        };
        self.set_pixels(&self.left, left);
        self.set_pixels(&self.top, top);
        self.set_pixels(&self.width, width);
        self.set_pixels(&self.height, height);
        self.set_bool(&self.has_min, presentation.min.is_some());
        self.set_bool(&self.has_max, presentation.max.is_some());
        self.set_bool(&self.has_progress, presentation.progress.is_some());
        self.set_text(&self.title, presentation.title);
        self.set_text(&self.value, presentation.value);
        self.set_text(&self.min, presentation.min.unwrap_or_default());
        self.set_text(&self.max, presentation.max.unwrap_or_default());
        self.set_pixels(
            &self.progress_width,
            (width - 4.0).max(0.0) * presentation.progress.unwrap_or_default().clamp(0.0, 1.0),
        );
        self.set_pixels(&self.progress_height, (height - 4.0).max(0.0));
        let rml = interface.rml_ui();
        if let Some(document) = self.document {
            rml.document_show(document, None, None)?;
        }
        if let Some(context) = self.context {
            rml.context_pull_to_front(context)?;
            rml.context_update(context)?;
        }
        Ok(())
    }

    /// This is a transient screen plane. Hiding its document, rather than a
    /// bound class inside it, guarantees no previous drag frame remains drawn.
    pub(crate) fn hide(&self, interface: &NativeInterfaceRef) -> Result<(), Error> {
        if let Some(document) = self.document {
            interface.rml_ui().document_hide(document)?;
        }
        Ok(())
    }

    pub(crate) fn forget(&mut self) {
        self.context = None;
        self.document = None;
        self.has_min = None;
        self.has_max = None;
        self.has_progress = None;
        self.title = None;
        self.value = None;
        self.min = None;
        self.max = None;
        self.left = None;
        self.top = None;
        self.width = None;
        self.height = None;
        self.progress_width = None;
        self.progress_height = None;
    }

    pub(crate) fn dispose(&mut self, interface: &NativeInterfaceRef) {
        if !rml::context_is_alive(interface, CONTEXT, self.context) {
            self.forget();
            return;
        }
        let rml = interface.rml_ui();
        if let Some(document) = self.document.take() {
            let _ = rml.document_close(document);
        }
        if let Some(context) = self.context {
            let _ = rml.remove_data_model(context, MODEL);
        }
        if let Some(context) = self.context.take() {
            let _ = rml.remove_context(context);
        }
        self.forget();
    }

    fn ensure(&mut self, interface: &NativeInterfaceRef) -> Result<(), Error> {
        if rml::context_is_alive(interface, CONTEXT, self.context) {
            return Ok(());
        }
        self.forget();
        let rml = interface.rml_ui();
        let (context, created) = rml.create_context(CONTEXT)?;
        if !created {
            return Ok(());
        }
        let geometry = interface.display().get_view_geometry()?;
        rml.context_set_dimensions(context, geometry.viewSizeX, geometry.viewSizeY)?;
        let _ = rml.context_enable_mouse_cursor(context, false);
        let model = rml.create_data_model(context, MODEL)?;
        self.bind(&model)?;
        let (document, created) = rml.context_create_document(context, "body")?;
        if !created {
            let _ = rml.remove_context(context);
            self.forget();
            return Ok(());
        }
        rml.document_append_to_style_sheet(document, STYLE)?;
        rml.element_set_inner_rml(document, MARKUP)?;
        self.context = Some(context);
        self.document = Some(document);
        Ok(())
    }

    fn bind(&mut self, model: &RmlDataModel<'static>) -> Result<(), Error> {
        self.has_min = Some(model.bind("has_min", false)?);
        self.has_max = Some(model.bind("has_max", false)?);
        self.has_progress = Some(model.bind("has_progress", false)?);
        self.title = Some(model.bind("title", String::new())?);
        self.value = Some(model.bind("value", String::new())?);
        self.min = Some(model.bind("min", String::new())?);
        self.max = Some(model.bind("max", String::new())?);
        self.left = Some(model.bind("left", RmlPixels(0.0))?);
        self.top = Some(model.bind("top", RmlPixels(0.0))?);
        self.width = Some(model.bind("width", RmlPixels(0.0))?);
        self.height = Some(model.bind("height", RmlPixels(0.0))?);
        self.progress_width = Some(model.bind("progress_width", RmlPixels(0.0))?);
        self.progress_height = Some(model.bind("progress_height", RmlPixels(0.0))?);
        Ok(())
    }

    fn set_bool(&self, binding: &Option<RmlDataVariable<'static, bool>>, value: bool) {
        if let Some(binding) = binding {
            let _ = binding.set(value);
        }
    }

    fn set_text(&self, binding: &Option<RmlDataVariable<'static, String>>, value: String) {
        if let Some(binding) = binding {
            let _ = binding.set(value);
        }
    }

    fn set_pixels(&self, binding: &Option<RmlDataVariable<'static, RmlPixels>>, value: f32) {
        if let Some(binding) = binding {
            let _ = binding.set(RmlPixels(value));
        }
    }
}
