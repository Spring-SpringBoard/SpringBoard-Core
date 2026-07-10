use spring_native::prelude::{Error, NativeInterfaceRef};

use crate::sbc::panels::field::{
    element_by_id, escape_rml, on_blur, on_enter, ChangeQueue, Field, FieldValue, InteractionQueue,
};

/// Single-line text, mirroring `RmlUiStringField` in
/// `scen_edit/view/rmlui_fields.lua`.
pub(crate) struct StringField {
    name: String,
    title: String,
    value: String,
    width: u32,
    element: Option<u64>,
}

impl StringField {
    pub(crate) fn new(name: &str, title: &str, value: &str) -> Self {
        StringField {
            name: name.to_string(),
            title: title.to_string(),
            value: value.to_string(),
            width: 200,
            element: None,
        }
    }

    pub(crate) fn width(mut self, width: u32) -> Self {
        self.width = width;
        self
    }
}

impl Field for StringField {
    fn name(&self) -> &str {
        &self.name
    }

    fn generate_rml(&self) -> String {
        format!(
            concat!(
                r#"<div class="field-row">"#,
                r#"<label class="field-label">{title}:</label>"#,
                r#"<input type="text" id="field-{n}" class="field-input" style="width: {width}px;" value="{value}"/>"#,
                r#"</div>"#,
            ),
            title = escape_rml(self.title.trim_end_matches(':')),
            n = self.name,
            width = self.width,
            value = escape_rml(&self.value),
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
            // Never on "change": a text input fires that per keystroke.
            on_enter(interface, e, self.name.clone(), changes)?;
            on_blur(interface, e, self.name.clone(), changes)?;
        }
        Ok(())
    }

    fn read_from_dom(&mut self, interface: &NativeInterfaceRef) -> Result<FieldValue, Error> {
        if let Some(e) = self.element {
            if let Ok(Some(text)) = interface.rml_ui().element_get_value(e) {
                self.value = text;
            }
        }
        Ok(FieldValue::Text(self.value.clone()))
    }

    fn write_to_dom(&self, interface: &NativeInterfaceRef) -> Result<(), Error> {
        if let Some(e) = self.element {
            interface
                .rml_ui()
                .element_set_attribute(e, "value", &self.value)?;
        }
        Ok(())
    }

    fn set_value(&mut self, value: &FieldValue) {
        if let FieldValue::Text(t) = value {
            self.value = t.clone();
        }
    }

    fn value(&self) -> FieldValue {
        FieldValue::Text(self.value.clone())
    }

    /// A text input has no separate display element: it is always editable, so
    /// a stale blur after Enter must not commit twice.
    fn is_text_edit(&self) -> bool {
        true
    }
}
