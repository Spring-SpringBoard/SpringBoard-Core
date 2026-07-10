use spring_native::prelude::{Error, NativeInterfaceRef};

use crate::sbc::panels::field::{
    element_by_id, escape_rml, on_pointer, ChangeQueue, Field, FieldValue, InteractionQueue,
};

/// A file path chosen from the asset picker, mirroring `RmlUiAssetField`.
/// Clicking the button opens the picker; the manager writes the result back.
pub(crate) struct AssetField {
    name: String,
    title: String,
    value: String,
    root: String,
    extensions: Vec<String>,
    element: Option<u64>,
}

impl AssetField {
    pub(crate) fn new(name: &str, title: &str, root: &str) -> Self {
        AssetField {
            name: name.to_string(),
            title: title.to_string(),
            value: String::new(),
            root: root.to_string(),
            extensions: Vec::new(),
            element: None,
        }
    }

    pub(crate) fn extensions(mut self, extensions: &[&str]) -> Self {
        self.extensions = extensions.iter().map(|e| e.to_string()).collect();
        self
    }

    fn button_rml(&self) -> String {
        // Show just the file name; the full VFS path does not fit the button.
        let shown = self
            .value
            .rsplit('/')
            .next()
            .filter(|s| !s.is_empty())
            .unwrap_or("(none)");
        format!(
            r#"<span class="field-button-title">{title}:</span><span class="field-button-value">{shown}</span>"#,
            title = escape_rml(self.title.trim_end_matches(':')),
            shown = escape_rml(shown),
        )
    }
}

impl Field for AssetField {
    fn name(&self) -> &str {
        &self.name
    }

    fn generate_rml(&self) -> String {
        format!(
            r#"<div class="field-row"><button id="field-{n}" class="field-composite-button field-asset-button">{button}</button></div>"#,
            n = self.name,
            button = self.button_rml(),
        )
    }

    fn bind(
        &mut self,
        interface: &NativeInterfaceRef,
        document: u64,
        _changes: &ChangeQueue,
        interactions: &InteractionQueue,
    ) -> Result<(), Error> {
        self.element = element_by_id(interface, document, &format!("field-{}", self.name));
        if let Some(e) = self.element {
            on_pointer(interface, e, self.name.clone(), interactions)?;
        }
        Ok(())
    }

    fn read_from_dom(&mut self, _interface: &NativeInterfaceRef) -> Result<FieldValue, Error> {
        Ok(FieldValue::Text(self.value.clone()))
    }

    fn write_to_dom(&self, interface: &NativeInterfaceRef) -> Result<(), Error> {
        if let Some(e) = self.element {
            interface
                .rml_ui()
                .element_set_inner_rml(e, &self.button_rml())?;
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

    fn asset_info(&self) -> Option<(String, Vec<String>)> {
        Some((self.root.clone(), self.extensions.clone()))
    }
}
