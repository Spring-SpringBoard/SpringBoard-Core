//! Row shapes shared by more than one panel or editor.

use spring_native::{RmlFieldType, RmlValueRef};

use crate::sbc::rml::rows::Row;

pub(crate) struct TextRow {
    pub text: String,
    pub muted: bool,
}

impl Row for TextRow {
    const FIELDS: &'static [(&'static str, RmlFieldType)] = &[
        ("text", RmlFieldType::String),
        ("muted", RmlFieldType::Bool),
    ];

    fn values<'a>(&'a self, out: &mut Vec<RmlValueRef<'a>>) {
        out.push(RmlValueRef::String(&self.text));
        out.push(RmlValueRef::Bool(self.muted));
    }
}

pub(crate) struct IconRow {
    pub label: String,
    pub icon: String,
    pub tooltip: String,
    pub pressed: bool,
    pub disabled: bool,
}

impl Row for IconRow {
    const FIELDS: &'static [(&'static str, RmlFieldType)] = &[
        ("label", RmlFieldType::String),
        ("icon", RmlFieldType::String),
        ("tooltip", RmlFieldType::String),
        ("pressed", RmlFieldType::Bool),
        ("disabled", RmlFieldType::Bool),
    ];

    fn values<'a>(&'a self, out: &mut Vec<RmlValueRef<'a>>) {
        out.push(RmlValueRef::String(&self.label));
        out.push(RmlValueRef::String(&self.icon));
        out.push(RmlValueRef::String(&self.tooltip));
        out.push(RmlValueRef::Bool(self.pressed));
        out.push(RmlValueRef::Bool(self.disabled));
    }
}

pub(crate) struct OptionRow {
    pub value: String,
    pub label: String,
}

impl Row for OptionRow {
    const FIELDS: &'static [(&'static str, RmlFieldType)] = &[
        ("value", RmlFieldType::String),
        ("label", RmlFieldType::String),
    ];

    fn values<'a>(&'a self, out: &mut Vec<RmlValueRef<'a>>) {
        out.push(RmlValueRef::String(&self.value));
        out.push(RmlValueRef::String(&self.label));
    }
}

pub(crate) struct ChoiceRow {
    pub label: String,
    pub detail: String,
    pub selected: bool,
    pub highlighted: bool,
}

impl Row for ChoiceRow {
    const FIELDS: &'static [(&'static str, RmlFieldType)] = &[
        ("label", RmlFieldType::String),
        ("detail", RmlFieldType::String),
        ("selected", RmlFieldType::Bool),
        ("highlighted", RmlFieldType::Bool),
    ];

    fn values<'a>(&'a self, out: &mut Vec<RmlValueRef<'a>>) {
        out.push(RmlValueRef::String(&self.label));
        out.push(RmlValueRef::String(&self.detail));
        out.push(RmlValueRef::Bool(self.selected));
        out.push(RmlValueRef::Bool(self.highlighted));
    }
}

pub(crate) struct StatusRow {
    pub label: String,
    pub positive: bool,
}

impl Row for StatusRow {
    const FIELDS: &'static [(&'static str, RmlFieldType)] = &[
        ("label", RmlFieldType::String),
        ("positive", RmlFieldType::Bool),
    ];

    fn values<'a>(&'a self, out: &mut Vec<RmlValueRef<'a>>) {
        out.push(RmlValueRef::String(&self.label));
        out.push(RmlValueRef::Bool(self.positive));
    }
}
