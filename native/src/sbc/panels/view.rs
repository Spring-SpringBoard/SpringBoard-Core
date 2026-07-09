use spring_native::prelude::{Error, NativeInterfaceRef};

use crate::sbc::panels::field::element_by_id;

const UI_CONTEXT: &str = "sbc_native_panel";
const UI_BODY: &str = include_str!("ui.rml");
const UI_STYLE: &str = include_str!("ui.rcss");

/// Owns the RmlUi context, document, and root elements for the panel.
/// Handles lifecycle (create/show/hide/dispose) and hit-testing.
pub(crate) struct PanelView {
    context: Option<u64>,
    document: Option<u64>,
    root: Option<u64>,
    content: Option<u64>,
}

impl Default for PanelView {
    fn default() -> Self {
        PanelView {
            context: None,
            document: None,
            root: None,
            content: None,
        }
    }
}

impl PanelView {
    /// True once the context + document have been created.
    pub(crate) fn is_ready(&self) -> bool {
        self.context.is_some() && self.document.is_some()
    }

    /// Create the RmlUi context + document if the engine is ready. Returns
    /// `true` if newly created (caller should rebuild editor content).
    pub(crate) fn ensure(&mut self, interface: &NativeInterfaceRef) -> Result<bool, Error> {
        if self.is_ready() {
            return Ok(false);
        }
        let rml = interface.rml_ui();
        if !rml.is_ready()? {
            return Ok(false);
        }

        let (ctx, ok) = rml.create_context(UI_CONTEXT)?;
        if !ok {
            return Ok(false);
        }
        let geom = interface.display().get_view_geometry()?;
        let _ = rml.context_set_dimensions(ctx, geom.viewSizeX, geom.viewSizeY);

        let (doc, ok) = rml.context_create_document(ctx, "body")?;
        if !ok {
            return Ok(false);
        }
        rml.document_set_title(doc, "Native Panel")?;
        rml.document_append_to_style_sheet(doc, UI_STYLE)?;
        rml.element_set_inner_rml(doc, UI_BODY)?;
        rml.document_show(doc, None, None)?;
        let _ = rml.context_enable_mouse_cursor(ctx, true);
        let _ = rml.context_pull_document_to_front(ctx, doc);

        self.context = Some(ctx);
        self.document = Some(doc);
        self.root = element_by_id(interface, doc, "native-panel");
        self.content = element_by_id(interface, doc, "panel-content");
        Ok(true)
    }

    /// Sync context dimensions + update RmlUi internal state.
    pub(crate) fn update(&mut self, interface: &NativeInterfaceRef) -> Result<(), Error> {
        if let Some(ctx) = self.context {
            let geom = interface.display().get_view_geometry()?;
            let _ = interface
                .rml_ui()
                .context_set_dimensions(ctx, geom.viewSizeX, geom.viewSizeY);
            interface.rml_ui().context_update(ctx)?;
        }
        Ok(())
    }

    /// Render the context to screen.
    pub(crate) fn draw(&mut self, interface: &NativeInterfaceRef) -> Result<(), Error> {
        if let Some(ctx) = self.context {
            interface.rml_ui().context_render(ctx)?;
        }
        Ok(())
    }

    /// Teardown: close document, remove context.
    pub(crate) fn dispose(&mut self, interface: &NativeInterfaceRef) {
        let rml = interface.rml_ui();
        if let Some(doc) = self.document.take() {
            let _ = rml.document_close(doc);
        }
        if let Some(ctx) = self.context.take() {
            let _ = rml.remove_context(ctx);
        }
        self.root = None;
        self.content = None;
    }

    /// Hit-test: is the point inside the panel's root element?
    pub(crate) fn contains(&self, interface: &NativeInterfaceRef, x: i32, y: i32) -> bool {
        self.root
            .and_then(|r| {
                interface
                    .rml_ui()
                    .element_is_point_within_element(r, x as f32, y as f32)
                    .ok()
            })
            .unwrap_or(false)
    }

    pub(crate) fn context_handle(&self) -> Option<u64> {
        self.context
    }
    pub(crate) fn document_handle(&self) -> Option<u64> {
        self.document
    }
    pub(crate) fn content_handle(&self) -> Option<u64> {
        self.content
    }

    /// Look up the panel-header element to set its text.
    pub(crate) fn header_element(&self, interface: &NativeInterfaceRef) -> Option<u64> {
        self.document
            .and_then(|doc| element_by_id(interface, doc, "panel-header"))
    }
}
