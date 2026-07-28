use spring_native::{
    prelude::{Error, NativeInterfaceRef},
    RmlDataModel, RmlDataVariable,
};

use crate::sbc::panels::field::{
    element_by_id, escape_rml, format_number, on_blur, on_enter, on_pointer, ChangeQueue, Field,
    FieldValue, InteractionQueue,
};

const DEFAULT_DECIMALS: usize = 3;

/// Numeric field with dual-mode interaction: drag the button to adjust the
/// value, click (without dragging) to type a new value.
pub(crate) struct NumericField {
    name: String,
    title: String,
    tooltip: Option<String>,
    value: f32,
    step: f32,
    /// Whether the caller chose the step, or it is still the default.
    step_set: bool,
    min: Option<f32>,
    max: Option<f32>,
    decimals: usize,
    compact: bool,
    edit_elem: Option<u64>,
    editing: bool,
    display_value: Option<RmlDataVariable<'static, String>>,
    input_value: Option<RmlDataVariable<'static, String>>,
    editing_value: Option<RmlDataVariable<'static, bool>>,
    dragging_value: Option<RmlDataVariable<'static, bool>>,
}

impl NumericField {
    pub(crate) fn new(name: impl Into<String>, title: impl Into<String>, value: f32) -> Self {
        Self {
            name: name.into(),
            title: title.into(),
            value,
            step: 0.01,
            step_set: false,
            min: None,
            max: None,
            decimals: DEFAULT_DECIMALS,
            compact: false,
            edit_elem: None,
            editing: false,
            display_value: None,
            input_value: None,
            editing_value: None,
            dragging_value: None,
            tooltip: None,
        }
    }

    pub(crate) fn with_tooltip(mut self, tooltip: &str) -> Self {
        self.tooltip = Some(tooltip.to_string());
        self
    }

    pub(crate) fn step(mut self, step: f32) -> Self {
        self.step = step;
        self.step_set = true;
        self
    }

    pub(crate) fn min(mut self, min: f32) -> Self {
        self.min = Some(min);
        self
    }
    pub(crate) fn max(mut self, max: f32) -> Self {
        self.max = Some(max);
        self
    }
    pub(crate) fn decimals(mut self, decimals: usize) -> Self {
        self.decimals = decimals;
        self
    }
    pub(crate) fn compact(mut self) -> Self {
        self.compact = true;
        self
    }

    #[allow(dead_code)]
    pub(crate) fn get(&self) -> f32 {
        self.value
    }

    /// How much one pixel of drag moves the value.
    ///
    /// Lua's rule (`NumericField:init`): a bounded field crosses its whole range
    /// in ~200px, so a 10..5000 size field moves ~25 per pixel. A fixed 1-per-
    /// pixel makes those fields crawl.
    fn drag_step(&self) -> f32 {
        if self.step_set {
            return self.step;
        }
        match (self.min, self.max) {
            (Some(min), Some(max)) if max > min => (max - min) / 200.0,
            _ => 1.0,
        }
    }

    fn clamp(&self, v: f32) -> f32 {
        v.max(self.min.unwrap_or(f32::MIN))
            .min(self.max.unwrap_or(f32::MAX))
    }

    fn display_text(&self) -> String {
        format_number(self.value, self.decimals)
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

    fn dragging_binding_name(&self) -> String {
        format!("{}_dragging", self.binding_name())
    }

    fn display_markup(&self) -> String {
        format!("{{{{ {} }}}}", self.binding_name())
    }

    fn sync_display_value(&self) -> Result<(), Error> {
        if let Some(value) = &self.display_value {
            value.set(self.display_text())?;
        }
        Ok(())
    }

    fn sync_input_value(&self) -> Result<(), Error> {
        if let Some(value) = &self.input_value {
            value.set(self.display_text())?;
        }
        Ok(())
    }

    fn show_edit(&mut self, interface: &NativeInterfaceRef) {
        self.editing = true;
        let _ = self.sync_input_value();
        if let Some(editing) = &self.editing_value {
            let _ = editing.set(true);
        }
        if let Some(e) = self.edit_elem {
            let _ = interface.rml_ui().element_focus(e);
            // Select the value so typing replaces it rather than appending.
            let _ = interface.rml_ui().element_form_control_input_select(e);
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

impl Field for NumericField {
    fn name(&self) -> &str {
        &self.name
    }

    fn tooltip(&self) -> Option<&str> {
        self.tooltip.as_deref()
    }

    fn prepare_data_model(&mut self, model: &RmlDataModel<'static>) -> Result<(), Error> {
        self.display_value = Some(model.bind(&self.binding_name(), self.display_text())?);
        self.input_value = Some(model.bind(&self.input_binding_name(), self.display_text())?);
        self.editing_value = Some(model.bind(&self.editing_binding_name(), false)?);
        self.dragging_value = Some(model.bind(&self.dragging_binding_name(), false)?);
        Ok(())
    }

    fn generate_rml(&self) -> String {
        // Same markup as RmlUiNumericField in scen_edit/view/rmlui_fields.lua.
        let width = if self.compact { 78 } else { 140 };
        format!(
            concat!(
                r#"<div class="field-row">"#,
                r#"<button id="field-{n}" class="field-composite-button field-numeric-button" style="width: {width}px;" data-class-hidden="{editing}" data-class-dragging="{dragging}"><span class="field-button-title">{title}:</span><span class="field-button-value">{value}</span></button>"#,
                r#"<input type="text" id="field-{n}-input" class="field-input field-numeric-input" style="width: {width}px;" data-class-hidden="!{editing}" data-value="{input_value}"/>"#,
                r#"</div>"#,
            ),
            n = self.name,
            width = width,
            title = escape_rml(self.title.trim_end_matches(':')),
            value = self.display_markup(),
            input_value = self.input_binding_name(),
            editing = self.editing_binding_name(),
            dragging = self.dragging_binding_name(),
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

        if let Some(e) = element_by_id(interface, document, &format!("field-{}", self.name)) {
            on_pointer(interface, e, self.name.clone(), interactions)?;
        }
        if let Some(e) = self.edit_elem {
            // Commit on Enter or on losing focus, never on "change": that
            // fires once per keystroke, dispatching a command per character.
            on_enter(interface, e, self.name.clone(), changes)?;
            on_blur(interface, e, self.name.clone(), changes)?;
        }
        Ok(())
    }

    fn read_from_dom(&mut self, interface: &NativeInterfaceRef) -> Result<FieldValue, Error> {
        if let Some(e) = self.edit_elem {
            if let Ok(Some(text)) = interface.rml_ui().element_get_value(e) {
                self.value = self.clamp(text.parse().unwrap_or(self.value));
            }
        }
        self.show_display(interface);
        Ok(FieldValue::Number(self.value))
    }

    fn write_to_dom(&self, interface: &NativeInterfaceRef) -> Result<(), Error> {
        let _ = interface;
        self.sync_display_value()?;
        self.sync_input_value()?;
        Ok(())
    }

    fn set_value(&mut self, value: &FieldValue) {
        if let FieldValue::Number(v) = value {
            // Programmatic updates (for example loading editor state) must
            // obey the same bounds as typed and dragged values.
            self.value = self.clamp(*v);
        }
    }

    fn value(&self) -> FieldValue {
        FieldValue::Number(self.value)
    }

    fn drag(&mut self, dx: f32, interface: &NativeInterfaceRef) {
        self.value = self.clamp(self.value + dx * self.drag_step());
        let _ = interface;
        let _ = self.sync_display_value();
        if let Some(dragging) = &self.dragging_value {
            let _ = dragging.set(true);
        }
    }

    fn drag_end(&mut self, interface: &NativeInterfaceRef) -> Option<FieldValue> {
        let _ = interface;
        if let Some(dragging) = &self.dragging_value {
            let _ = dragging.set(false);
        }
        Some(FieldValue::Number(self.value))
    }

    fn begin_edit(&mut self, interface: &NativeInterfaceRef) {
        if !self.editing {
            self.show_edit(interface);
        }
    }

    fn select_edit(&mut self, interface: &NativeInterfaceRef) {
        if self.editing {
            if let Some(e) = self.edit_elem {
                let _ = interface.rml_ui().element_focus(e);
                let _ = interface.rml_ui().element_form_control_input_select(e);
            }
        }
    }

    fn end_edit(&mut self, interface: &NativeInterfaceRef) {
        if self.editing {
            self.show_display(interface);
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn programmatic_values_obey_declared_bounds() {
        let mut field = NumericField::new("strength", "Strength", 1.0)
            .min(0.0)
            .max(1.0);

        field.set_value(&FieldValue::Number(10.0));
        assert_eq!(field.value(), FieldValue::Number(1.0));

        field.set_value(&FieldValue::Number(-1.0));
        assert_eq!(field.value(), FieldValue::Number(0.0));
    }
}
