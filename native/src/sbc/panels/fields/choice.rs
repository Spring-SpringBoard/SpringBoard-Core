use spring_native::prelude::{Error, NativeInterfaceRef};

use crate::sbc::panels::field::{
    element_by_id, escape_rml, on_change, ChangeQueue, Field, FieldValue, InteractionQueue,
};

/// Dropdown select field.
pub(crate) struct ChoiceField {
    name: String,
    title: String,
    tooltip: Option<String>,
    value: String,
    items: Vec<String>,
    element: Option<u64>,
}

impl ChoiceField {
    pub(crate) fn new(
        name: impl Into<String>,
        title: impl Into<String>,
        items: Vec<String>,
    ) -> Self {
        ChoiceField {
            name: name.into(),
            title: title.into(),
            value: items.first().cloned().unwrap_or_default(),
            items,
            tooltip: None,
            element: None,
        }
    }

    pub(crate) fn with_tooltip(mut self, tooltip: &str) -> Self {
        self.tooltip = Some(tooltip.to_string());
        self
    }

    #[allow(dead_code)]
    pub(crate) fn get(&self) -> &str {
        &self.value
    }
}

impl Field for ChoiceField {
    fn name(&self) -> &str {
        &self.name
    }

    fn tooltip(&self) -> Option<&str> {
        self.tooltip.as_deref()
    }

    fn generate_rml(&self) -> String {
        let title = escape_rml(self.title.trim_end_matches(':'));
        let options: String = self
            .items
            .iter()
            .map(|item| {
                let sel = if *item == self.value { " selected" } else { "" };
                format!(
                    r#"<option value="{}"{}>{}</option>"#,
                    escape_rml(item),
                    sel,
                    escape_rml(item)
                )
            })
            .collect();
        // Like numeric and colour fields, the caption belongs to the control
        // itself. Keeping it inside the border makes a compact ChoiceField a
        // single visual unit rather than a loose label plus a wide select.
        format!(r#"<div class="field-row"><div class="select-wrapper field-choice"><span class="select-label">{title}:</span>"#)
            + &format!(
                r#"<select id="field-{n}" class="field-input field-select">{opts}</select>"#,
                n = self.name,
                opts = options,
            )
            // The arrow is drawn by CSS as a triangle so it is independent of
            // the installed font's Unicode glyph coverage.
            + r#"<span class="select-arrow"></span></div></div>"#
    }

    fn bind(
        &mut self,
        interface: &NativeInterfaceRef,
        document: u64,
        changes: &ChangeQueue,
        _interactions: &InteractionQueue,
    ) -> Result<(), Error> {
        let id = format!("field-{}", self.name);
        if let Some(elem) = element_by_id(interface, document, &id) {
            self.element = Some(elem);
            on_change(interface, elem, self.name.clone(), changes)?;
        }
        Ok(())
    }

    fn read_from_dom(&mut self, interface: &NativeInterfaceRef) -> Result<FieldValue, Error> {
        if let Some(e) = self.element {
            if let Ok(Some(v)) = interface.rml_ui().element_get_value(e) {
                self.value = v;
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
        if let FieldValue::Text(v) = value {
            self.value = v.clone();
        }
    }

    fn value(&self) -> FieldValue {
        FieldValue::Text(self.value.clone())
    }
}
