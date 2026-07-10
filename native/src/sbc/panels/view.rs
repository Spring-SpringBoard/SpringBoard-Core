use std::cell::RefCell;
use std::rc::Rc;

use spring_native::prelude::{Error, NativeInterfaceRef};

use crate::sbc::panels::field::{element_by_id, escape_rml};
use crate::sbc::panels::registry::{editors_for, Tab};

const UI_CONTEXT: &str = "sbc_native_ui";
const UI_BODY: &str = include_str!("ui.rml");
const UI_STYLE: &str = include_str!("ui.rcss");

/// A shell-level click, queued by an RmlUi event listener and drained by the
/// manager on the next tick. Rebuilding the DOM inside a listener would free the
/// elements RmlUi is still dispatching to.
#[derive(Debug, Clone)]
pub(crate) enum ShellEvent {
    TabClicked(Tab),
    EditorClicked(&'static str),
}

pub(crate) type ShellQueue = Rc<RefCell<Vec<ShellEvent>>>;

/// Owns the RmlUi context, document and shell chrome (tab bar, editor button
/// strip, content host) of the native right-hand panel.
pub(crate) struct PanelView {
    context: Option<u64>,
    document: Option<u64>,
    root: Option<u64>,
    content: Option<u64>,
    events: ShellQueue,
    current_tab: Tab,
    active_editor: Option<&'static str>,
}

impl Default for PanelView {
    fn default() -> Self {
        PanelView {
            context: None,
            document: None,
            root: None,
            content: None,
            events: Rc::new(RefCell::new(Vec::new())),
            current_tab: Tab::Objects,
            active_editor: None,
        }
    }
}

impl PanelView {
    pub(crate) fn is_ready(&self) -> bool {
        self.context.is_some() && self.document.is_some()
    }

    pub(crate) fn active_editor(&self) -> Option<&'static str> {
        self.active_editor
    }

    pub(crate) fn drain_events(&self) -> Vec<ShellEvent> {
        self.events.borrow_mut().drain(..).collect()
    }

    /// Create the context + document if the engine is ready. Returns `true` if
    /// newly created.
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
        rml.document_set_title(doc, "SpringBoard")?;
        rml.document_append_to_style_sheet(doc, UI_STYLE)?;
        rml.element_set_inner_rml(doc, UI_BODY)?;
        rml.document_show(doc, None, None)?;
        let _ = rml.context_enable_mouse_cursor(ctx, true);
        let _ = rml.context_pull_document_to_front(ctx, doc);

        self.context = Some(ctx);
        self.document = Some(doc);
        self.root = element_by_id(interface, doc, "native-panel");
        self.content = element_by_id(interface, doc, "main-content");

        self.build_tab_bar(interface)?;
        self.build_editor_buttons(interface)?;
        Ok(true)
    }

    // ── Shell chrome ───────────────────────────────────────────────

    fn build_tab_bar(&mut self, interface: &NativeInterfaceRef) -> Result<(), Error> {
        let Some(doc) = self.document else {
            return Ok(());
        };
        let Some(bar) = element_by_id(interface, doc, "tab-bar") else {
            return Ok(());
        };

        let mut html = String::new();
        for tab in Tab::ALL {
            let active = if tab == self.current_tab { " active" } else { "" };
            html.push_str(&format!(
                r#"<button id="tab-{name}" class="tab-button{active}">{name}</button>"#,
                name = tab.as_str(),
            ));
        }
        interface.rml_ui().element_set_inner_rml(bar, &html)?;

        for tab in Tab::ALL {
            let id = format!("tab-{}", tab.as_str());
            let Some(button) = element_by_id(interface, doc, &id) else {
                continue;
            };
            let queue = self.events.clone();
            interface
                .rml_ui()
                .element_add_event_listener(button, "click", false, move || {
                    queue.borrow_mut().push(ShellEvent::TabClicked(tab));
                })?;
        }
        Ok(())
    }

    /// Rebuild the editor button strip for the current tab.
    pub(crate) fn build_editor_buttons(
        &mut self,
        interface: &NativeInterfaceRef,
    ) -> Result<(), Error> {
        let Some(doc) = self.document else {
            return Ok(());
        };
        let Some(panel) = element_by_id(interface, doc, "editor-button-panel") else {
            return Ok(());
        };

        let specs = editors_for(self.current_tab);
        let mut html = String::new();
        for spec in &specs {
            let pressed = if Some(spec.name) == self.active_editor {
                " pressed"
            } else {
                ""
            };
            html.push_str(&format!(
                r#"<button id="editor-{name}" class="editor-button{pressed}" title="{tooltip}">"#,
                name = spec.name,
                tooltip = escape_rml(spec.tooltip),
            ));
            html.push_str(&format!(r#"<img src="{}"/>"#, spec.image));
            html.push_str(&format!(
                r#"<div class="editor-button-label">{}</div></button>"#,
                escape_rml(spec.caption),
            ));
        }
        interface.rml_ui().element_set_inner_rml(panel, &html)?;

        for spec in specs {
            let id = format!("editor-{}", spec.name);
            let Some(button) = element_by_id(interface, doc, &id) else {
                continue;
            };
            let queue = self.events.clone();
            let name = spec.name;
            interface
                .rml_ui()
                .element_add_event_listener(button, "click", false, move || {
                    queue.borrow_mut().push(ShellEvent::EditorClicked(name));
                })?;
        }
        Ok(())
    }

    /// Switch tab: restyle the tab buttons, rebuild the strip, clear content.
    /// Matches Chili, where changing tabs closes the open editor.
    pub(crate) fn set_tab(&mut self, interface: &NativeInterfaceRef, tab: Tab) -> Result<(), Error> {
        if self.current_tab == tab {
            return Ok(());
        }
        let Some(doc) = self.document else {
            return Ok(());
        };
        self.current_tab = tab;
        self.active_editor = None;

        for candidate in Tab::ALL {
            let id = format!("tab-{}", candidate.as_str());
            if let Some(button) = element_by_id(interface, doc, &id) {
                let _ = interface
                    .rml_ui()
                    .element_set_class(button, "active", candidate == tab);
            }
        }
        self.build_editor_buttons(interface)?;
        self.clear_content(interface)
    }

    pub(crate) fn set_active_editor(
        &mut self,
        interface: &NativeInterfaceRef,
        name: Option<&'static str>,
    ) -> Result<(), Error> {
        self.active_editor = name;
        self.build_editor_buttons(interface)
    }

    pub(crate) fn clear_content(&self, interface: &NativeInterfaceRef) -> Result<(), Error> {
        if let Some(content) = self.content {
            interface.rml_ui().element_set_inner_rml(content, "")?;
        }
        Ok(())
    }

    // ── Lifecycle ──────────────────────────────────────────────────

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

    /// The engine renders every RmlUi context in RmlGui::RenderFrame, between
    /// BeginFrame and PresentFrame. Calling context_render here would submit
    /// geometry outside that frame, where it is dropped.
    pub(crate) fn draw(&mut self, _interface: &NativeInterfaceRef) -> Result<(), Error> {
        Ok(())
    }

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
}
