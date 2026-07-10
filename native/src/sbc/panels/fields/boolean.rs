use spring_native::prelude::{Error, NativeInterfaceRef};

use crate::sbc::panels::field::{
    element_by_id, escape_rml, on_change, ChangeQueue, Field, FieldValue, InteractionQueue,
};

/// Checkbox, mirroring `RmlUiBooleanField` in `scen_edit/view/rmlui_fields.lua`.
pub(crate) struct BooleanField {
    name: String,
    title: String,
    value: bool,
    element: Option<u64>,
}

impl BooleanField {
    pub(crate) fn new(name: &str, title: &str, value: bool) -> Self {
        BooleanField {
            name: name.to_string(),
            title: title.to_string(),
            value,
            element: None,
        }
    }
}

impl Field for BooleanField {
    fn name(&self) -> &str {
        &self.name
    }

    fn generate_rml(&self) -> String {
        let checked = if self.value {
            r#" checked="checked""#
        } else {
            ""
        };
        format!(
            concat!(
                r#"<div class="field-row">"#,
                r#"<label class="field-label">{title}:</label>"#,
                r#"<input type="checkbox" id="field-{n}" class="field-checkbox"{checked}/>"#,
                r#"</div>"#,
            ),
            title = escape_rml(self.title.trim_end_matches(':')),
            n = self.name,
            checked = checked,
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
            on_change(interface, e, self.name.clone(), changes)?;
        }
        Ok(())
    }

    /// RmlUi marks a checkbox by the *presence* of the `checked` attribute (it
    /// sets it to ""), so comparing its value to "checked" always reads false.
    fn read_from_dom(&mut self, interface: &NativeInterfaceRef) -> Result<FieldValue, Error> {
        if let Some(e) = self.element {
            self.value = interface
                .rml_ui()
                .element_has_attribute(e, "checked")
                .unwrap_or(false);
        }
        Ok(FieldValue::Bool(self.value))
    }

    fn write_to_dom(&self, interface: &NativeInterfaceRef) -> Result<(), Error> {
        let Some(e) = self.element else {
            return Ok(());
        };
        let rml = interface.rml_ui();
        if self.value {
            rml.element_set_attribute(e, "checked", "")?;
        } else {
            rml.element_remove_attribute(e, "checked")?;
        }
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
