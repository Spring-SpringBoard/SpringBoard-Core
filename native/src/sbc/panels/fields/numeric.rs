use spring_native::prelude::{Error, NativeInterfaceRef};

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
    display_elem: Option<u64>,
    edit_elem: Option<u64>,
    editing: bool,
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
            display_elem: None,
            edit_elem: None,
            editing: false,
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

    fn button_rml(&self) -> String {
        format!(
            r#"<span class="field-button-title">{title}:</span><span class="field-button-value">{val}</span>"#,
            title = escape_rml(self.title.trim_end_matches(':')),
            val = self.display_text(),
        )
    }

    /// Visibility is a `hidden` class, as in the Lua RmlUi fields. An inline
    /// `style` would beat the stylesheet and leave the input unstyled (it
    /// rendered invisible).
    fn show_edit(&mut self, interface: &NativeInterfaceRef) {
        self.editing = true;
        let text = self.display_text();
        let rml = interface.rml_ui();
        if let Some(e) = self.display_elem {
            let _ = rml.element_set_class(e, "hidden", true);
        }
        if let Some(e) = self.edit_elem {
            let _ = rml.element_set_class(e, "hidden", false);
            let _ = rml.element_set_attribute(e, "value", &text);
            let _ = rml.element_focus(e);
        }
    }

    fn show_display(&mut self, interface: &NativeInterfaceRef) {
        self.editing = false;
        let rml = interface.rml_ui();
        if let Some(e) = self.display_elem {
            let _ = rml.element_set_class(e, "hidden", false);
            let _ = rml.element_set_inner_rml(e, &self.button_rml());
        }
        if let Some(e) = self.edit_elem {
            let _ = rml.element_set_class(e, "hidden", true);
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

    fn generate_rml(&self) -> String {
        // Same markup as RmlUiNumericField in scen_edit/view/rmlui_fields.lua.
        let width = if self.compact { 78 } else { 140 };
        format!(
            concat!(
                r#"<div class="field-row">"#,
                r#"<button id="field-{n}" class="field-composite-button field-numeric-button" style="width: {width}px;">{button}</button>"#,
                r#"<input type="text" id="field-{n}-input" class="field-input field-numeric-input hidden" style="width: {width}px;" value="{val}"/>"#,
                r#"</div>"#,
            ),
            n = self.name,
            width = width,
            button = self.button_rml(),
            val = self.display_text(),
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

        if let Some(e) = self.display_elem {
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
        let val = self.display_text();
        if let Some(e) = self.display_elem {
            interface
                .rml_ui()
                .element_set_inner_rml(e, &self.button_rml())?;
        }
        if let Some(e) = self.edit_elem {
            interface.rml_ui().element_set_attribute(e, "value", &val)?;
        }
        Ok(())
    }

    fn set_value(&mut self, value: &FieldValue) {
        if let FieldValue::Number(v) = value {
            self.value = *v;
        }
    }

    fn value(&self) -> FieldValue {
        FieldValue::Number(self.value)
    }

    fn drag(&mut self, dx: f32, interface: &NativeInterfaceRef) {
        self.value = self.clamp(self.value + dx * self.drag_step());
        if let Some(e) = self.display_elem {
            let rml = interface.rml_ui();
            // Rewrite the whole button: it carries a title span and a value
            // span, and replacing its markup with the bare number loses both.
            let _ = rml.element_set_inner_rml(e, &self.button_rml());
            let _ = rml.element_set_class(e, "dragging", true);
        }
    }

    fn drag_end(&mut self, interface: &NativeInterfaceRef) -> Option<FieldValue> {
        if let Some(e) = self.display_elem {
            let _ = interface.rml_ui().element_set_class(e, "dragging", false);
        }
        Some(FieldValue::Number(self.value))
    }

    fn begin_edit(&mut self, interface: &NativeInterfaceRef) {
        if !self.editing {
            self.show_edit(interface);
        }
    }

    fn end_edit(&mut self, interface: &NativeInterfaceRef) {
        if self.editing {
            self.show_display(interface);
        }
    }
}
