use spring_native::prelude::{Error, NativeInterfaceRef};

use crate::sbc::panels::field::{
    element_by_id, escape_rml, on_blur, on_enter, on_pointer, ChangeQueue, Field, FieldValue,
    InteractionQueue,
};

/// Single-line text, mirroring `RmlUiStringField` in
/// `scen_edit/view/rmlui_fields.lua`.
pub(crate) struct StringField {
    name: String,
    title: String,
    tooltip: Option<String>,
    value: String,
    width: u32,
    display_elem: Option<u64>,
    edit_elem: Option<u64>,
    editing: bool,
}

impl StringField {
    pub(crate) fn new(name: &str, title: &str, value: &str) -> Self {
        StringField {
            name: name.to_string(),
            title: title.to_string(),
            value: value.to_string(),
            width: 200,
            tooltip: None,
            display_elem: None,
            edit_elem: None,
            editing: false,
        }
    }

    pub(crate) fn with_tooltip(mut self, tooltip: &str) -> Self {
        self.tooltip = Some(tooltip.to_string());
        self
    }

    fn button_rml(&self) -> String {
        format!(
            r#"<span class="field-button-title">{title}:</span><span class="field-button-value">{value}</span>"#,
            title = escape_rml(self.title.trim_end_matches(':')),
            value = escape_rml(&self.value),
        )
    }

    fn show_edit(&mut self, interface: &NativeInterfaceRef) {
        self.editing = true;
        let rml = interface.rml_ui();
        if let Some(element) = self.display_elem {
            let _ = rml.element_set_class(element, "hidden", true);
        }
        if let Some(element) = self.edit_elem {
            let _ = rml.element_set_class(element, "hidden", false);
            let _ = rml.element_set_attribute(element, "value", &self.value);
            let _ = rml.element_focus(element);
            let _ = rml.element_form_control_input_select(element);
        }
    }

    fn show_display(&mut self, interface: &NativeInterfaceRef) {
        self.editing = false;
        let markup = self.button_rml();
        let rml = interface.rml_ui();
        if let Some(element) = self.display_elem {
            let _ = rml.element_set_class(element, "hidden", false);
            let _ = rml.element_set_inner_rml(element, &markup);
        }
        if let Some(element) = self.edit_elem {
            let _ = rml.element_set_class(element, "hidden", true);
        }
    }
}

impl Field for StringField {
    fn name(&self) -> &str {
        &self.name
    }

    fn tooltip(&self) -> Option<&str> {
        self.tooltip.as_deref()
    }

    fn generate_rml(&self) -> String {
        format!(
            concat!(
                r#"<div class="field-row">"#,
                r#"<button id="field-{n}" class="field-composite-button field-string-button" style="width: {width}px;">{button}</button>"#,
                r#"<input type="text" id="field-{n}-input" class="field-input field-string-input hidden" style="width: {width}px;" value="{value}"/>"#,
                r#"</div>"#,
            ),
            n = self.name,
            width = self.width,
            button = self.button_rml(),
            value = escape_rml(&self.value),
        )
    }

    fn bind(
        &mut self,
        interface: &NativeInterfaceRef,
        document: u64,
        changes: &ChangeQueue,
        interactions: &InteractionQueue,
    ) -> Result<(), Error> {
        self.display_elem = element_by_id(interface, document, &format!("field-{}", self.name));
        self.edit_elem = element_by_id(interface, document, &format!("field-{}-input", self.name));
        if let Some(element) = self.display_elem {
            on_pointer(interface, element, self.name.clone(), interactions)?;
        }
        if let Some(element) = self.edit_elem {
            // Never on "change": a text input fires that per keystroke.
            on_enter(interface, element, self.name.clone(), changes)?;
            on_blur(interface, element, self.name.clone(), changes)?;
        }
        Ok(())
    }

    fn read_from_dom(&mut self, interface: &NativeInterfaceRef) -> Result<FieldValue, Error> {
        if let Some(element) = self.edit_elem {
            if let Ok(Some(text)) = interface.rml_ui().element_get_value(element) {
                self.value = text;
            }
        }
        self.show_display(interface);
        Ok(FieldValue::Text(self.value.clone()))
    }

    fn write_to_dom(&self, interface: &NativeInterfaceRef) -> Result<(), Error> {
        if let Some(element) = self.display_elem {
            interface
                .rml_ui()
                .element_set_inner_rml(element, &self.button_rml())?;
        }
        if let Some(element) = self.edit_elem {
            interface
                .rml_ui()
                .element_set_attribute(element, "value", &self.value)?;
        }
        Ok(())
    }

    /// Click without drag: focus and select the whole value, so typing
    /// replaces it (the standard click-to-edit behaviour).
    fn begin_edit(&mut self, interface: &NativeInterfaceRef) {
        if !self.editing {
            self.show_edit(interface);
        }
    }

    fn select_edit(&mut self, interface: &NativeInterfaceRef) {
        if self.editing {
            if let Some(element) = self.edit_elem {
                let _ = interface.rml_ui().element_focus(element);
                let _ = interface
                    .rml_ui()
                    .element_form_control_input_select(element);
            }
        }
    }

    fn end_edit(&mut self, interface: &NativeInterfaceRef) {
        if self.editing {
            self.show_display(interface);
        }
    }

    fn set_value(&mut self, value: &FieldValue) {
        if let FieldValue::Text(t) = value {
            self.value = t.clone();
        }
    }

    fn value(&self) -> FieldValue {
        FieldValue::Text(self.value.clone())
    }
}
