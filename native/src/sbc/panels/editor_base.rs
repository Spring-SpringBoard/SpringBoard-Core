//! Shared plumbing for editors, so a view is only its fields and its command
//! dispatch. Everything here is what every editor would otherwise copy.

use spring_native::prelude::{Error, NativeInterfaceRef};

use crate::sbc::panels::field::{ChangeQueue, Field, FieldValue, InteractionQueue};

#[macro_export]
macro_rules! sb_field_editor_methods {
    () => {
        fn drag_field(
            &mut self,
            name: &str,
            dx: f32,
            interface: &spring_native::prelude::NativeInterfaceRef,
        ) -> bool {
            self.fields.drag(name, dx, interface)
        }

        fn drag_end_field(
            &mut self,
            name: &str,
            interface: &spring_native::prelude::NativeInterfaceRef,
        ) -> bool {
            self.fields.drag_end(name, interface)
        }

        fn begin_edit_field(
            &mut self,
            name: &str,
            interface: &spring_native::prelude::NativeInterfaceRef,
        ) {
            self.fields.begin_edit(name, interface)
        }

        fn cancel_edit_field(
            &mut self,
            name: &str,
            interface: &spring_native::prelude::NativeInterfaceRef,
        ) {
            self.fields.cancel_edit(name, interface)
        }

        fn field_value(&self, name: &str) -> $crate::sbc::panels::field::FieldValue {
            self.fields.value(name)
        }

        fn set_field_value(
            &mut self,
            name: &str,
            value: $crate::sbc::panels::field::FieldValue,
            interface: &spring_native::prelude::NativeInterfaceRef,
        ) {
            self.fields
                .set($crate::sbc::panels::editor_base::resolve_base(name), value);
            let _ = self.fields.write_values(interface);
        }

        fn field_asset(&self, name: &str) -> Option<(String, Vec<String>)> {
            self.fields.asset_info(name)
        }
    };
}

#[macro_export]
macro_rules! sb_delegate_editor_methods {
    ($target:ident) => {
        fn drag_field(
            &mut self,
            name: &str,
            dx: f32,
            interface: &spring_native::prelude::NativeInterfaceRef,
        ) -> bool {
            self.$target.drag_field(name, dx, interface)
        }

        fn drag_end_field(
            &mut self,
            name: &str,
            interface: &spring_native::prelude::NativeInterfaceRef,
        ) -> bool {
            self.$target.drag_end_field(name, interface)
        }

        fn begin_edit_field(
            &mut self,
            name: &str,
            interface: &spring_native::prelude::NativeInterfaceRef,
        ) {
            self.$target.begin_edit_field(name, interface)
        }

        fn cancel_edit_field(
            &mut self,
            name: &str,
            interface: &spring_native::prelude::NativeInterfaceRef,
        ) {
            self.$target.cancel_edit_field(name, interface)
        }

        fn field_value(&self, name: &str) -> $crate::sbc::panels::field::FieldValue {
            self.$target.field_value(name)
        }

        fn set_field_value(
            &mut self,
            name: &str,
            value: $crate::sbc::panels::field::FieldValue,
            interface: &spring_native::prelude::NativeInterfaceRef,
        ) {
            self.$target.set_field_value(name, value, interface)
        }

        fn field_asset(&self, _name: &str) -> Option<(String, Vec<String>)> {
            None
        }
    };
}

/// Resolve a change-event name to its base field name. Colour sub-fields like
/// `"fogColor-r"` map to `"fogColor"`.
pub(crate) fn resolve_base(name: &str) -> &str {
    match name.rsplit_once('-') {
        Some((base, "r" | "g" | "b" | "hex")) => base,
        _ => name,
    }
}

/// Declarative editor body layout. Editors should describe their controls with
/// these items and let `FieldSet::generate_rml` do the markup assembly.
pub(crate) enum Layout<'a> {
    Field(&'a str),
    FieldOwned(String),
    Group(&'a [&'a str]),
    GroupOwned(Vec<String>),
    Section(&'a str),
    SectionOwned(String),
    /// Standalone markup for controls that are not fields, such as brush action
    /// strips and grids. Keep field rows out of this variant.
    Raw(String),
    /// Field/group rows that need stable ids for runtime visibility toggles.
    IdentifiedField(&'a str),
    IdentifiedGroup(&'a [&'a str]),
}

/// Same markup as the section separators Lua's `Editor:AddControl` emits.
fn section_rml(caption: &str) -> String {
    format!(
        r#"<div class="field-section"><div class="field-section-label">{caption}</div><div class="field-section-line"></div></div>"#
    )
}

/// A row of fields laid out side by side, like Lua's `GroupField`.
///
/// Each field renders itself as a `field-row`, which is a block-level flex
/// container and so would take a whole line. Lua rewrites those to
/// `field-inline` when grouping; do the same.
fn group_rml(fields: &[String]) -> String {
    let inner: String = fields.iter().map(|f| grouped_field_rml(f, None)).collect();
    format!(r#"<div class="field-group">{inner}</div>"#)
}

fn grouped_field_rml(field: &str, id: Option<&str>) -> String {
    let target = match id {
        Some(id) => format!(r#"<div class="field-inline" id="row-{id}">"#),
        None => r#"<div class="field-inline">"#.to_string(),
    };
    field
        .replacen(
            r#"<div class="field-row field-boolean field-boolean-long">"#,
            &target.replacen(
                "field-inline",
                "field-inline field-boolean field-boolean-long",
                1,
            ),
            1,
        )
        .replacen(
            r#"<div class="field-row field-boolean">"#,
            &target.replacen("field-inline", "field-inline field-boolean", 1),
            1,
        )
        .replacen(r#"<div class="field-row">"#, &target, 1)
}

fn identified_field_rml(field: String, name: &str) -> String {
    field
        .replacen(
            r#"<div class="field-row field-boolean field-boolean-long">"#,
            &format!(
                r#"<div class="field-inline field-boolean field-boolean-long" id="row-{name}">"#
            ),
            1,
        )
        .replacen(
            r#"<div class="field-row field-boolean">"#,
            &format!(r#"<div class="field-row field-boolean" id="row-{name}">"#),
            1,
        )
        .replacen(
            r#"<div class="field-row">"#,
            &format!(r#"<div class="field-row" id="row-{name}">"#),
            1,
        )
}

fn identified_group_rml(fields: &[(&str, String)]) -> String {
    let inner: String = fields
        .iter()
        .map(|(name, field)| grouped_field_rml(field, Some(name)))
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

    pub(crate) fn generate_rml(&self, layout: &[Layout<'_>]) -> String {
        let mut html = String::new();
        for item in layout {
            match item {
                Layout::Field(name) => html.push_str(&self.rml(name)),
                Layout::FieldOwned(name) => html.push_str(&self.rml(name)),
                Layout::Group(names) => {
                    let fields: Vec<String> = names.iter().map(|name| self.rml(name)).collect();
                    html.push_str(&group_rml(&fields));
                }
                Layout::GroupOwned(names) => {
                    let fields: Vec<String> = names.iter().map(|name| self.rml(name)).collect();
                    html.push_str(&group_rml(&fields));
                }
                Layout::Section(caption) => html.push_str(&section_rml(caption)),
                Layout::SectionOwned(caption) => html.push_str(&section_rml(caption)),
                Layout::Raw(markup) => html.push_str(markup),
                Layout::IdentifiedField(name) => {
                    html.push_str(&identified_field_rml(self.rml(name), name));
                }
                Layout::IdentifiedGroup(names) => {
                    let fields: Vec<(&str, String)> =
                        names.iter().map(|name| (*name, self.rml(name))).collect();
                    html.push_str(&identified_group_rml(&fields));
                }
            }
        }
        html
    }

    pub(crate) fn asset_info(&self, name: &str) -> Option<(String, Vec<String>)> {
        self.get(resolve_base(name)).and_then(|f| f.asset_info())
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

    pub(crate) fn boolean(&self, name: &str) -> bool {
        match self.get(name).map(|f| f.value()) {
            Some(FieldValue::Bool(v)) => v,
            _ => false,
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
            // Every field renders as `field-<name>`, so one place can give them
            // all hover text -- no field type has to know about tooltips.
            if let Some(tooltip) = field.tooltip() {
                let id = format!("field-{}", field.name());
                if let Some(element) =
                    crate::sbc::panels::field::element_by_id(interface, document, &id)
                {
                    crate::sbc::panels::field::bind_tooltip(interface, document, element, tooltip)?;
                }
            }
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
