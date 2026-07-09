use spring_native::prelude::{Error, NativeInterfaceRef};

use crate::sbc::panels::field::{
    element_by_id, escape_rml, format_number, on_change, on_pointer, ChangeQueue, Field,
    FieldValue, InteractionQueue,
};

const DEFAULT_DECIMALS: usize = 3;

/// Numeric field with dual-mode interaction: drag the button to adjust the
/// value, click (without dragging) to type a new value.
pub(crate) struct NumericField {
    name: String,
    title: String,
    value: f32,
    step: f32,
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
            min: None,
            max: None,
            decimals: DEFAULT_DECIMALS,
            compact: false,
            display_elem: None,
            edit_elem: None,
            editing: false,
        }
    }

    pub(crate) fn step(mut self, step: f32) -> Self {
        self.step = step;
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

    fn clamp(&self, v: f32) -> f32 {
        v.max(self.min.unwrap_or(f32::MIN))
            .min(self.max.unwrap_or(f32::MAX))
    }

    fn display_text(&self) -> String {
        format_number(self.value, self.decimals)
    }

    fn show_edit(&mut self, interface: &NativeInterfaceRef) {
        self.editing = true;
        let text = self.display_text();
        if let Some(e) = self.display_elem {
            let _ = interface
                .rml_ui()
                .element_set_attribute(e, "style", "display: none;");
        }
        if let Some(e) = self.edit_elem {
            let _ = interface.rml_ui().element_set_attribute(e, "style", "");
            let _ = interface.rml_ui().element_set_attribute(e, "value", &text);
            let _ = interface.rml_ui().element_focus(e);
        }
    }

    fn show_display(&mut self, interface: &NativeInterfaceRef) {
        self.editing = false;
        if let Some(e) = self.display_elem {
            let _ = interface.rml_ui().element_set_attribute(e, "style", "");
        }
        if let Some(e) = self.edit_elem {
            let _ = interface
                .rml_ui()
                .element_set_attribute(e, "style", "display: none;");
        }
    }
}

impl Field for NumericField {
    fn name(&self) -> &str {
        &self.name
    }

    fn generate_rml(&self) -> String {
        let title = escape_rml(self.title.trim_end_matches(':'));
        let val = self.display_text();
        let display_cls = if self.compact {
            "numeric-display compact"
        } else {
            "numeric-display"
        };
        let row_open = if self.compact {
            format!(r#"<div class="field-inline"><span class="field-label-small">{title}</span>"#)
        } else {
            format!(r#"<div class="field-row"><span class="field-label">{title}:</span>"#)
        };
        format!(
            r#"{row_open}<button id="field-{n}-display" class="{cls}">{val}</button><input type="text" id="field-{n}-edit" class="numeric-edit" value="{val}" style="display: none;"/></div>"#,
            row_open = row_open,
            n = self.name,
            cls = display_cls,
            val = val,
        )
    }

    fn bind(
        &mut self,
        interface: &NativeInterfaceRef,
        document: u64,
        changes: &ChangeQueue,
        interactions: &InteractionQueue,
    ) -> Result<(), Error> {
        self.display_elem =
            element_by_id(interface, document, &format!("field-{}-display", self.name));
        self.edit_elem = element_by_id(interface, document, &format!("field-{}-edit", self.name));

        if let Some(e) = self.display_elem {
            on_pointer(interface, e, self.name.clone(), interactions)?;
        }
        if let Some(e) = self.edit_elem {
            on_change(interface, e, self.name.clone(), changes)?;
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
            interface.rml_ui().element_set_inner_rml(e, &val)?;
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
        self.value = self.clamp(self.value + dx * self.step);
        if let Some(e) = self.display_elem {
            let _ = interface
                .rml_ui()
                .element_set_inner_rml(e, &self.display_text());
        }
    }

    fn drag_end(&mut self, _interface: &NativeInterfaceRef) -> Option<FieldValue> {
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
