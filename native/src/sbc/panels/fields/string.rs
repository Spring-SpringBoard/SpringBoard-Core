use spring_native::{
    prelude::{Error, NativeInterfaceRef},
    RmlDataModel, RmlDataVariable,
};

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
    edit_elem: Option<u64>,
    editing: bool,
    display_value: Option<RmlDataVariable<'static, String>>,
    input_value: Option<RmlDataVariable<'static, String>>,
    editing_value: Option<RmlDataVariable<'static, bool>>,
}

impl StringField {
    pub(crate) fn new(name: &str, title: &str, value: &str) -> Self {
        StringField {
            name: name.to_string(),
            title: title.to_string(),
            value: value.to_string(),
            width: 200,
            tooltip: None,
            edit_elem: None,
            editing: false,
            display_value: None,
            input_value: None,
            editing_value: None,
        }
    }

    pub(crate) fn with_tooltip(mut self, tooltip: &str) -> Self {
        self.tooltip = Some(tooltip.to_string());
        self
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

    fn input_binding_name(&self) -> String {
        format!("{}_input", self.binding_name())
    }

    fn editing_binding_name(&self) -> String {
        format!("{}_editing", self.binding_name())
    }

    fn display_markup(&self) -> String {
        format!("{{{{ {} }}}}", self.binding_name())
    }

    fn sync_display_value(&self) -> Result<(), Error> {
        if let Some(value) = &self.display_value {
            value.set(self.value.clone())?;
        }
        Ok(())
    }

    fn sync_input_value(&self) -> Result<(), Error> {
        if let Some(value) = &self.input_value {
            value.set(self.value.clone())?;
        }
        Ok(())
    }

    fn show_edit(&mut self, interface: &NativeInterfaceRef) {
        self.editing = true;
        let _ = self.sync_input_value();
        if let Some(editing) = &self.editing_value {
            let _ = editing.set(true);
        }
        if let Some(element) = self.edit_elem {
            let _ = interface.rml_ui().element_focus(element);
            let _ = interface
                .rml_ui()
                .element_form_control_input_select(element);
        }
    }

    fn show_display(&mut self, _interface: &NativeInterfaceRef) {
        self.editing = false;
        let _ = self.sync_display_value();
        if let Some(editing) = &self.editing_value {
            let _ = editing.set(false);
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

    fn prepare_data_model(&mut self, model: &RmlDataModel<'static>) -> Result<(), Error> {
        self.display_value = Some(model.bind(&self.binding_name(), self.value.clone())?);
        self.input_value = Some(model.bind(&self.input_binding_name(), self.value.clone())?);
        self.editing_value = Some(model.bind(&self.editing_binding_name(), false)?);
        Ok(())
    }

    fn generate_rml(&self) -> String {
        format!(
            concat!(
                r#"<div class="field-row">"#,
                r#"<button id="field-{n}" class="field-composite-button field-string-button" style="width: {width}px;" data-class-hidden="{editing}"><span class="field-button-title">{title}:</span><span class="field-button-value">{value}</span></button>"#,
                r#"<input type="text" id="field-{n}-input" class="field-input field-string-input" style="width: {width}px;" data-class-hidden="!{editing}" data-value="{input_value}"/>"#,
                r#"</div>"#,
            ),
            n = self.name,
            width = self.width,
            title = escape_rml(self.title.trim_end_matches(':')),
            value = self.display_markup(),
            input_value = self.input_binding_name(),
            editing = self.editing_binding_name(),
        )
    }

    fn bind(
        &mut self,
        interface: &NativeInterfaceRef,
        document: u64,
        changes: &ChangeQueue,
        interactions: &InteractionQueue,
    ) -> Result<(), Error> {
        self.edit_elem = element_by_id(interface, document, &format!("field-{}-input", self.name));
        if let Some(element) = element_by_id(interface, document, &format!("field-{}", self.name)) {
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
        let _ = interface;
        self.sync_display_value()?;
        self.sync_input_value()?;
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
