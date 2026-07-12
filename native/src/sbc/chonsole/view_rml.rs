//! RmlUi document lifetime and pointer/key forwarding for Chonsole.

use spring_native::prelude::{Error, NativeInterfaceRef};

use crate::sbc::rml::{self, element_by_id};

const UI_CONTEXT: &str = "sbc_native_chonsole";
const UI_BODY: &str = include_str!("ui.rml");
const UI_STYLE: &str = include_str!("ui.rcss");

pub(super) struct ChonsoleRml {
    context: Option<u64>,
    document: Option<u64>,
    root: Option<u64>,
    lines: Option<u64>,
    mouse_captured: bool,
    enabled: bool,
}

impl Default for ChonsoleRml {
    fn default() -> Self {
        Self {
            context: None,
            document: None,
            root: None,
            lines: None,
            mouse_captured: false,
            enabled: true,
        }
    }
}

impl ChonsoleRml {
    pub(super) fn has_document(&self) -> bool {
        self.document.is_some()
    }

    pub(super) fn context_is_alive(&self, interface: &NativeInterfaceRef) -> bool {
        rml::context_is_alive(interface, UI_CONTEXT, self.context)
    }

    /// Returns true only when a document was created during this call.
    pub(super) fn ensure(&mut self, interface: &NativeInterfaceRef) -> Result<bool, Error> {
        if !self.enabled {
            return Ok(false);
        }
        if self.context.is_some() && self.document.is_some() {
            if self.context_is_alive(interface) {
                return Ok(false);
            }
            self.forget();
        }
        let rml = interface.rml_ui();
        if !rml.is_ready()? {
            return Ok(false);
        }
        let (context, created) = rml.create_context(UI_CONTEXT)?;
        if !created {
            return Ok(false);
        }
        let geometry = interface.display().get_view_geometry()?;
        let _ = rml.context_set_dimensions(context, geometry.viewSizeX, geometry.viewSizeY);
        let (document, created) = rml.context_create_document(context, "body")?;
        if !created {
            return Ok(false);
        }
        rml.document_set_title(document, "Native Chonsole")?;
        rml.document_append_to_style_sheet(document, UI_STYLE)?;
        rml.element_set_inner_rml(document, UI_BODY)?;
        rml.document_show(document, None, None)?;
        self.context = Some(context);
        self.document = Some(document);
        self.root = element_by_id(interface, document, "native-chonsole");
        self.lines = element_by_id(interface, document, "native-chonsole-lines");
        Ok(true)
    }

    pub(super) fn update(&self, interface: &NativeInterfaceRef) -> Result<(), Error> {
        let Some(context) = self.context else {
            return Ok(());
        };
        let geometry = interface.display().get_view_geometry()?;
        let rml = interface.rml_ui();
        let _ = rml.context_set_dimensions(context, geometry.viewSizeX, geometry.viewSizeY);
        rml.context_update(context)?;
        Ok(())
    }

    pub(super) fn dispose(&mut self, interface: &NativeInterfaceRef) {
        if !self.context_is_alive(interface) {
            self.forget();
            return;
        }
        let rml = interface.rml_ui();
        if let Some(document) = self.document.take() {
            let _ = rml.document_close(document);
        }
        if let Some(context) = self.context.take() {
            let _ = rml.remove_context(context);
        }
        self.forget();
    }

    pub(super) fn set_visible(
        &mut self,
        interface: &NativeInterfaceRef,
        visible: bool,
    ) -> Result<(), Error> {
        let Some(document) = self.document else {
            return Ok(());
        };
        let rml = interface.rml_ui();
        if visible {
            rml.document_show(document, None, None)?;
            if let Some(context) = self.context {
                let _ = rml.context_enable_mouse_cursor(context, true);
                let _ = rml.context_pull_document_to_front(context, document);
            }
        } else {
            rml.document_hide(document)?;
            self.mouse_captured = false;
            if let Some(context) = self.context {
                let _ = rml.context_process_mouse_leave(context);
            }
        }
        Ok(())
    }

    pub(super) fn refresh(
        &mut self,
        interface: &NativeInterfaceRef,
        body: &str,
    ) -> Result<(), Error> {
        let Some(document) = self.document else {
            return Ok(());
        };
        let rml = interface.rml_ui();
        if let Some(root) = self.root {
            rml.element_set_inner_rml(root, body)?;
        } else {
            rml.element_set_inner_rml(document, UI_BODY)?;
        }
        self.root = element_by_id(interface, document, "native-chonsole");
        self.lines = element_by_id(interface, document, "native-chonsole-lines");
        if let Some(lines) = self.lines {
            let _ = rml.element_set_scroll_top(lines, 1_000_000);
        }
        Ok(())
    }

    pub(super) fn process_key_up(
        &self,
        interface: &NativeInterfaceRef,
        key_code: i32,
    ) -> Result<bool, Error> {
        self.context.map_or(Ok(false), |context| {
            interface
                .rml_ui()
                .context_process_key_up(context, key_code, 0)
        })
    }

    pub(super) fn process_text_input(
        &self,
        interface: &NativeInterfaceRef,
        utf8: &str,
    ) -> Result<bool, Error> {
        self.context.map_or(Ok(false), |context| {
            interface.rml_ui().context_process_text_input(context, utf8)
        })
    }

    pub(super) fn mouse_move(
        &mut self,
        interface: &NativeInterfaceRef,
        visible: bool,
        x: i32,
        y: i32,
    ) -> Result<bool, Error> {
        if !visible {
            return Ok(false);
        }
        let Some(context) = self.context else {
            return Ok(false);
        };
        let inside = self.contains(interface, x, y)?;
        let interacting = interface.rml_ui().context_is_mouse_interacting(context)?;
        if !inside && !interacting {
            if self.mouse_captured {
                let _ = interface.rml_ui().context_process_mouse_leave(context);
            }
            self.mouse_captured = false;
            return Ok(false);
        }
        interface
            .rml_ui()
            .context_process_mouse_move(context, x as f32, y as f32, 0)?;
        self.mouse_captured = inside || interacting;
        Ok(inside || interacting)
    }

    pub(super) fn mouse_press(
        &mut self,
        interface: &NativeInterfaceRef,
        visible: bool,
        x: i32,
        y: i32,
        button: i32,
    ) -> Result<bool, Error> {
        if !visible {
            return Ok(false);
        }
        let Some(context) = self.context else {
            return Ok(false);
        };
        if !self.contains(interface, x, y)? && !self.mouse_captured {
            return Ok(false);
        }
        let rml = interface.rml_ui();
        rml.context_process_mouse_move(context, x as f32, y as f32, 0)?;
        self.mouse_captured = true;
        rml.context_process_mouse_button_down(context, button - 1, 0)
    }

    pub(super) fn mouse_release(
        &mut self,
        interface: &NativeInterfaceRef,
        visible: bool,
        x: i32,
        y: i32,
        button: i32,
    ) -> Result<(), Error> {
        if !visible {
            return Ok(());
        }
        let Some(context) = self.context else {
            return Ok(());
        };
        let rml = interface.rml_ui();
        rml.context_process_mouse_move(context, x as f32, y as f32, 0)?;
        let _ = rml.context_process_mouse_button_up(context, button - 1, 0);
        self.mouse_captured = rml.context_is_mouse_interacting(context).unwrap_or(false);
        Ok(())
    }

    pub(super) fn mouse_wheel(
        &self,
        interface: &NativeInterfaceRef,
        visible: bool,
        up: bool,
        value: f32,
    ) -> Result<bool, Error> {
        if !visible {
            return Ok(false);
        }
        let Some(context) = self.context else {
            return Ok(false);
        };
        let mouse = interface.input().get_mouse_state()?;
        if !self.contains(interface, mouse.x as i32, mouse.y as i32)? {
            return Ok(false);
        }
        interface.rml_ui().context_process_mouse_wheel(
            context,
            if up { value } else { -value },
            0.0,
            0,
        )
    }

    fn contains(&self, interface: &NativeInterfaceRef, x: i32, y: i32) -> Result<bool, Error> {
        self.root.map_or(Ok(false), |root| {
            interface
                .rml_ui()
                .element_is_point_within_element(root, x as f32, y as f32)
        })
    }

    fn forget(&mut self) {
        self.context = None;
        self.document = None;
        self.root = None;
        self.lines = None;
        self.mouse_captured = false;
    }
}
