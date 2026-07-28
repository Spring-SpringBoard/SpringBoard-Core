use spring_native::{
    prelude::{Error, NativeInterfaceRef},
    RmlDataModel, RmlDataVariable,
};

use crate::sbc::panels::field::{
    element_by_id, escape_rml, on_pointer, ChangeQueue, Field, FieldValue, InteractionQueue,
};

/// A file path chosen from the asset picker, mirroring `RmlUiAssetField`.
/// Clicking the button opens the picker; the manager writes the result back.
pub(crate) struct AssetField {
    name: String,
    title: String,
    tooltip: Option<String>,
    value: String,
    root: String,
    extensions: Vec<String>,
    element: Option<u64>,
    display_value: Option<RmlDataVariable<'static, String>>,
}

impl AssetField {
    pub(crate) fn new(name: &str, title: &str, root: &str) -> Self {
        AssetField {
            name: name.to_string(),
            title: title.to_string(),
            value: String::new(),
            root: root.to_string(),
            extensions: Vec::new(),
            tooltip: None,
            element: None,
            display_value: None,
        }
    }

    pub(crate) fn with_tooltip(mut self, tooltip: &str) -> Self {
        self.tooltip = Some(tooltip.to_string());
        self
    }

    pub(crate) fn extensions(mut self, extensions: &[&str]) -> Self {
        self.extensions = extensions.iter().map(|e| e.to_string()).collect();
        self
    }

    fn display_text(&self) -> String {
        self.value
            .rsplit('/')
            .next()
            .filter(|value| !value.is_empty())
            .unwrap_or("(none)")
            .to_string()
    }

    fn binding_name(&self) -> String {
        format!(
            "field_{}_display",
            self.name
                .chars()
                .map(|character| if character.is_ascii_alphanumeric() {
                    character
                } else {
                    '_'
                })
                .collect::<String>(),
        )
    }

    fn display_markup(&self) -> String {
        self.display_value
            .as_ref()
            .map(|_| format!("{{{{ {} }}}}", self.binding_name()))
            .unwrap_or_else(|| escape_rml(&self.display_text()))
    }

    fn sync_display_value(&self) -> Result<(), Error> {
        if let Some(value) = &self.display_value {
            value.set(self.display_text())?;
        }
        Ok(())
    }
}

impl Field for AssetField {
    fn name(&self) -> &str {
        &self.name
    }

    fn tooltip(&self) -> Option<&str> {
        self.tooltip.as_deref()
    }

    fn prepare_data_model(&mut self, model: &RmlDataModel<'static>) -> Result<(), Error> {
        self.display_value = Some(model.bind(&self.binding_name(), self.display_text())?);
        Ok(())
    }

    fn generate_rml(&self) -> String {
        format!(
            r#"<div class="field-row"><button id="field-{n}" class="field-composite-button field-asset-button"><span class="field-button-title">{title}:</span><span class="field-button-value">{value}</span></button></div>"#,
            n = self.name,
            title = escape_rml(self.title.trim_end_matches(':')),
            value = self.display_markup(),
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

    fn write_to_dom(&self, _interface: &NativeInterfaceRef) -> Result<(), Error> {
        if self.element.is_some() {
            self.sync_display_value()?;
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
