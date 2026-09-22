use std::cell::Cell;
use std::rc::Rc;

use spring_native::{
    prelude::{Error, NativeInterfaceRef},
    RmlDataModel,
};

use crate::sbc::panels::field::{
    element_by_id, escape_rml, ChangeQueue, CommitRequest, Field, FieldValue, InteractionQueue,
};

/// Full-width push button. Value is the press count, so each press registers as a change.
pub(crate) struct ButtonField {
    name: String,
    title: String,
    tooltip: Option<String>,
    presses: u32,
    clicked: Rc<Cell<bool>>,
}

impl ButtonField {
    pub(crate) fn new(name: &str, title: &str) -> Self {
        ButtonField {
            name: name.to_string(),
            title: title.to_string(),
            tooltip: None,
            presses: 0,
            clicked: Rc::new(Cell::new(false)),
        }
    }

    pub(crate) fn with_tooltip(mut self, tooltip: &str) -> Self {
        self.tooltip = Some(tooltip.to_string());
        self
    }
}

impl Field for ButtonField {
    fn name(&self) -> &str {
        &self.name
    }

    fn tooltip(&self) -> Option<&str> {
        self.tooltip.as_deref()
    }

    fn prepare_data_model(&mut self, _model: &RmlDataModel<'static>) -> Result<(), Error> {
        Ok(())
    }

    fn generate_rml(&self) -> String {
        format!(
            concat!(
                r#"<div class="field-row field-button">"#,
                r#"<button id="field-{n}" class="field-toggle theme-toggle theme-toggle--form field-push">"#,
                r#"<span class="field-toggle-label">{title}</span></button>"#,
                r#"</div>"#,
            ),
            n = self.name,
            title = escape_rml(&self.title),
        )
    }

    fn bind(
        &mut self,
        interface: &NativeInterfaceRef,
        document: u64,
        changes: &ChangeQueue,
        _interactions: &InteractionQueue,
    ) -> Result<(), Error> {
        let Some(element) = element_by_id(interface, document, &format!("field-{}", self.name))
        else {
            return Ok(());
        };
        let clicked = self.clicked.clone();
        let changes = changes.clone();
        let name = self.name.clone();
        interface
            .rml_ui()
            .element_add_event_listener(element, "click", false, move || {
                clicked.set(true);
                changes.borrow_mut().push(CommitRequest {
                    field: name.clone(),
                    from_blur: false,
                    revert: false,
                });
            })?;
        Ok(())
    }

    fn read_from_dom(&mut self, _interface: &NativeInterfaceRef) -> Result<FieldValue, Error> {
        if self.clicked.replace(false) {
            self.presses = self.presses.wrapping_add(1);
        }
        Ok(self.value())
    }

    fn write_to_dom(&self, _interface: &NativeInterfaceRef) -> Result<(), Error> {
        Ok(())
    }

    fn set_value(&mut self, value: &FieldValue) {
        // Control channel: setting any number presses it.
        if let FieldValue::Number(_) = value {
            self.presses = self.presses.wrapping_add(1);
        }
    }

    fn value(&self) -> FieldValue {
        FieldValue::Number(self.presses as f32)
    }
}
