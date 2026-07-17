use std::cell::Cell;
use std::rc::Rc;

use spring_native::prelude::{Error, NativeInterfaceRef};

use crate::sbc::panels::field::{
    element_by_id, escape_rml, ChangeQueue, CommitRequest, Field, FieldValue, InteractionQueue,
};

/// A full-width toggle button, mirroring `RmlUiBooleanField` in
/// `scen_edit/view/rmlui_fields.lua`.
///
/// RmlUi's stock checkbox is small and visually indistinguishable from a
/// browser control. A button lets it share the native Chonsole's selected
/// action treatment and gives the entire control a reliable click target.
pub(crate) struct BooleanField {
    name: String,
    title: String,
    tooltip: Option<String>,
    value: bool,
    element: Option<u64>,
    clicked: Rc<Cell<bool>>,
}

impl BooleanField {
    pub(crate) fn new(name: &str, title: &str, value: bool) -> Self {
        BooleanField {
            name: name.to_string(),
            title: title.to_string(),
            value,
            tooltip: None,
            element: None,
            clicked: Rc::new(Cell::new(false)),
        }
    }

    pub(crate) fn with_tooltip(mut self, tooltip: &str) -> Self {
        self.tooltip = Some(tooltip.to_string());
        self
    }

    fn button_rml(&self) -> String {
        format!(
            r#"<span class="field-toggle-label">{}</span><span class="field-toggle-switch"><span class="field-toggle-thumb"></span></span>"#,
            escape_rml(self.title.trim_end_matches(':')),
        )
    }
}

impl Field for BooleanField {
    fn name(&self) -> &str {
        &self.name
    }

    fn tooltip(&self) -> Option<&str> {
        self.tooltip.as_deref()
    }

    fn generate_rml(&self) -> String {
        let pressed = if self.value { " pressed" } else { "" };
        // A two-column toggle has room for roughly 23 Poppins characters plus
        // its switch. Long object-property captions need their own row rather
        // than becoming an accidental two-line button.
        let long = (self.title.chars().count() >= 24)
            .then_some(" field-boolean-long")
            .unwrap_or("");
        format!(
            concat!(
                r#"<div class="field-row field-boolean{long}">"#,
                r#"<button id="field-{n}" class="field-toggle{pressed}">{button}</button>"#,
                r#"</div>"#,
            ),
            n = self.name,
            pressed = pressed,
            button = self.button_rml(),
            long = long,
        )
    }

    fn bind(
        &mut self,
        interface: &NativeInterfaceRef,
        document: u64,
        changes: &ChangeQueue,
        _interactions: &InteractionQueue,
    ) -> Result<(), Error> {
        self.element = element_by_id(interface, document, &format!("field-{}", self.name));
        if let Some(e) = self.element {
            let clicked = self.clicked.clone();
            let changes = changes.clone();
            let name = self.name.clone();
            interface
                .rml_ui()
                .element_add_event_listener(e, "click", false, move || {
                    clicked.set(true);
                    changes.borrow_mut().push(CommitRequest {
                        field: name.clone(),
                        from_blur: false,
                        revert: false,
                    });
                })?;
        }
        Ok(())
    }

    fn read_from_dom(&mut self, interface: &NativeInterfaceRef) -> Result<FieldValue, Error> {
        if self.clicked.replace(false) {
            self.value = !self.value;
        }
        self.write_to_dom(interface)?;
        Ok(FieldValue::Bool(self.value))
    }

    fn write_to_dom(&self, interface: &NativeInterfaceRef) -> Result<(), Error> {
        let Some(e) = self.element else {
            return Ok(());
        };
        let rml = interface.rml_ui();
        rml.element_set_class(e, "pressed", self.value)?;
        rml.element_set_inner_rml(e, &self.button_rml())?;
        Ok(())
    }

    fn set_value(&mut self, value: &FieldValue) {
        if let FieldValue::Bool(b) = value {
            self.value = *b;
        }
    }

    fn value(&self) -> FieldValue {
        FieldValue::Bool(self.value)
    }
}
