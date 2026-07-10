//! Shared plumbing for editors, so a view is only its fields and its command
//! dispatch. Everything here is what every editor would otherwise copy.

use spring_native::prelude::{Error, NativeInterfaceRef};

use crate::sbc::panels::field::{ChangeQueue, Field, FieldValue, InteractionQueue};

/// Build a JSON command envelope for routing through `SBC::route()`.
pub(crate) fn envelope(class: &str, next: &mut u64, opts: serde_json::Value) -> String {
    let id = *next;
    *next += 1;
    serde_json::json!({
        "tag": "command",
        "data": {
            "className": class,
            "__cmd_id": id,
            "opts": opts,
        }
    })
    .to_string()
}

/// An envelope whose command takes its payload under a key other than `opts`
/// (`SetScenarioInfoCommand` deserializes a `data` object, for instance).
pub(crate) fn envelope_with(
    class: &str,
    next: &mut u64,
    key: &str,
    payload: serde_json::Value,
) -> String {
    let id = *next;
    *next += 1;
    serde_json::json!({
        "tag": "command",
        "data": {
            "className": class,
            "__cmd_id": id,
            key: payload,
        }
    })
    .to_string()
}

/// Resolve a change-event name to its base field name. Colour sub-fields like
/// `"fogColor-r"` map to `"fogColor"`.
pub(crate) fn resolve_base(name: &str) -> &str {
    match name.rsplit_once('-') {
        Some((base, "r" | "g" | "b" | "hex")) => base,
        _ => name,
    }
}

/// Same markup as the section separators Lua's `Editor:AddControl` emits.
pub(crate) fn section_rml(caption: &str) -> String {
    format!(
        r#"<div class="field-section"><div class="field-section-label">{caption}</div><div class="field-section-line"></div></div>"#
    )
}

/// A row of fields laid out side by side, like Lua's `GroupField`.
///
/// Each field renders itself as a `field-row`, which is a block-level flex
/// container and so would take a whole line. Lua rewrites those to
/// `field-inline` when grouping; do the same.
pub(crate) fn group_rml(fields: &[String]) -> String {
    let inner: String = fields
        .iter()
        .map(|f| f.replacen(r#"<div class="field-row">"#, r#"<div class="field-inline">"#, 1))
        .collect();
    format!(r#"<div class="field-group">{inner}</div>"#)
}

/// An editor's fields, with the generate/bind/read/write plumbing.
pub(crate) struct FieldSet {
    fields: Vec<Box<dyn Field>>,
}

impl FieldSet {
    pub(crate) fn new(fields: Vec<Box<dyn Field>>) -> Self {
        FieldSet { fields }
    }

    pub(crate) fn get(&self, name: &str) -> Option<&dyn Field> {
        self.fields.iter().find(|f| f.name() == name).map(|f| &**f)
    }

    pub(crate) fn get_mut(&mut self, name: &str) -> Option<&mut Box<dyn Field>> {
        self.fields.iter_mut().find(|f| f.name() == name)
    }

    pub(crate) fn rml(&self, name: &str) -> String {
        self.get(name).map(|f| f.generate_rml()).unwrap_or_default()
    }

    /// The field's colour, if it is one. Used to open the picker on it.
    pub(crate) fn color(&self, name: &str) -> Option<[f32; 4]> {
        match self.get(resolve_base(name)).map(|f| f.value()) {
            Some(FieldValue::Color(c)) => Some(c),
            _ => None,
        }
    }

    pub(crate) fn is_asset(&self, name: &str) -> bool {
        self.get(resolve_base(name)).is_some_and(|f| f.is_asset())
    }

    pub(crate) fn asset_info(&self, name: &str) -> Option<(String, Vec<String>)> {
        self.get(resolve_base(name)).and_then(|f| f.asset_info())
    }

    pub(crate) fn is_text_edit(&self, name: &str) -> bool {
        self.get(resolve_base(name)).is_some_and(|f| f.is_text_edit())
    }

    pub(crate) fn boolean(&self, name: &str) -> bool {
        matches!(self.get(name).map(|f| f.value()), Some(FieldValue::Bool(true)))
    }

    pub(crate) fn text(&self, name: &str) -> String {
        match self.get(name).map(|f| f.value()) {
            Some(FieldValue::Text(t)) => t,
            _ => String::new(),
        }
    }

    pub(crate) fn number(&self, name: &str) -> f32 {
        match self.get(name).map(|f| f.value()) {
            Some(FieldValue::Number(n)) => n,
            _ => 0.0,
        }
    }

    pub(crate) fn set(&mut self, name: &str, value: FieldValue) {
        if let Some(f) = self.get_mut(name) {
            f.set_value(&value);
        }
    }

    pub(crate) fn bind(
        &mut self,
        interface: &NativeInterfaceRef,
        document: u64,
        changes: &ChangeQueue,
        interactions: &InteractionQueue,
    ) -> Result<(), Error> {
        for field in &mut self.fields {
            field.bind(interface, document, changes, interactions)?;
        }
        Ok(())
    }

    pub(crate) fn write_values(&self, interface: &NativeInterfaceRef) -> Result<(), Error> {
        for field in &self.fields {
            field.write_to_dom(interface)?;
        }
        Ok(())
    }

    /// Read a committed field's value out of the DOM.
    pub(crate) fn read(&mut self, name: &str, interface: &NativeInterfaceRef) -> FieldValue {
        let base = resolve_base(name).to_string();
        self.get_mut(&base)
            .and_then(|f| f.read_from_dom(interface).ok())
            .unwrap_or(FieldValue::Text(String::new()))
    }

    /// The value a drag left behind; the DOM is not consulted.
    pub(crate) fn value(&self, name: &str) -> FieldValue {
        self.get(resolve_base(name))
            .map(|f| f.value())
            .unwrap_or(FieldValue::Text(String::new()))
    }

    pub(crate) fn drag(&mut self, name: &str, dx: f32, interface: &NativeInterfaceRef) -> bool {
        if let Some((base, sub)) = name.rsplit_once('-') {
            if matches!(sub, "r" | "g" | "b") {
                if let Some(f) = self.get_mut(base) {
                    f.prepare_drag(sub);
                    f.drag(dx, interface);
                    return true;
                }
            }
        }
        match self.get_mut(name) {
            Some(f) => {
                f.drag(dx, interface);
                true
            }
            None => false,
        }
    }

    pub(crate) fn drag_end(&mut self, name: &str, interface: &NativeInterfaceRef) -> bool {
        let base = resolve_base(name).to_string();
        match self.get_mut(&base) {
            Some(f) => {
                f.drag_end(interface);
                true
            }
            None => false,
        }
    }

    pub(crate) fn begin_edit(&mut self, name: &str, interface: &NativeInterfaceRef) {
        if let Some((base, sub)) = name.rsplit_once('-') {
            if matches!(sub, "r" | "g" | "b") {
                if let Some(f) = self.get_mut(base) {
                    f.begin_sub_edit(sub, interface);
                    return;
                }
            }
        }
        if let Some(f) = self.get_mut(name) {
            f.begin_edit(interface);
        }
    }

    pub(crate) fn cancel_edit(&mut self, name: &str, interface: &NativeInterfaceRef) {
        let base = resolve_base(name).to_string();
        if let Some(f) = self.get_mut(&base) {
            f.end_edit(interface);
        }
    }
}
