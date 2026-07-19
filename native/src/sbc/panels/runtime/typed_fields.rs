//! Typed model fields: a static def (data, `static`-declared per editor) plus
//! the live value. Editor code reads and writes through typed accessors; the
//! DOM plumbing reuses the dyn `Field` implementations underneath.

use spring_native::prelude::{Error, NativeInterfaceRef};

use crate::sbc::panels::field::{Field, FieldValue};
use crate::sbc::panels::fields::{ChoiceField, NumericField};
use crate::sbc::panels::grid::GridView;
use crate::sbc::panels::runtime::contract::{Brush, FieldMut, FieldRef};

// ── Number ─────────────────────────────────────────────────────────

pub(crate) struct NumDef {
    pub name: &'static str,
    pub label: &'static str,
    pub default: f32,
    pub min: Option<f32>,
    pub max: Option<f32>,
    pub step: Option<f32>,
    pub decimals: Option<usize>,
    pub tooltip: Option<&'static str>,
    pub brush: Option<Brush>,
}

impl NumDef {
    pub(crate) const BASE: NumDef = NumDef {
        name: "",
        label: "",
        default: 0.0,
        min: None,
        max: None,
        step: None,
        decimals: None,
        tooltip: None,
        brush: None,
    };

    /// Used in `static` position, so a bad def fails the build, not the run.
    pub(crate) const fn checked(self) -> Self {
        if let (Some(min), Some(max)) = (self.min, self.max) {
            assert!(min <= max);
        }
        if let Some(min) = self.min {
            assert!(min <= self.default);
        }
        if let Some(max) = self.max {
            assert!(self.default <= max);
        }
        if let Some(step) = self.step {
            assert!(step > 0.0);
        }
        self
    }
}

pub(crate) struct Num {
    def: &'static NumDef,
    inner: NumericField,
}

impl Num {
    pub(crate) fn of(def: &'static NumDef) -> Self {
        let mut inner = NumericField::new(def.name, def.label, def.default);
        if let Some(min) = def.min {
            inner = inner.min(min);
        }
        if let Some(max) = def.max {
            inner = inner.max(max);
        }
        if let Some(step) = def.step {
            inner = inner.step(step);
        }
        if let Some(decimals) = def.decimals {
            inner = inner.decimals(decimals);
        }
        if let Some(tooltip) = def.tooltip {
            inner = inner.with_tooltip(tooltip);
        }
        Num { def, inner }
    }

    pub(crate) fn get(&self) -> f32 {
        self.inner.get()
    }

    pub(crate) fn set(&mut self, value: f32) {
        self.inner.set_value(&FieldValue::Number(value));
    }

    pub(crate) fn entry(&self) -> FieldRef<'_> {
        FieldRef {
            field: &self.inner,
            brush: self.def.brush,
        }
    }

    pub(crate) fn entry_mut(&mut self) -> FieldMut<'_> {
        FieldMut {
            field: &mut self.inner,
            brush: self.def.brush,
        }
    }
}

// ── Choice ─────────────────────────────────────────────────────────

/// The options of a choice field are a real enum; the DOM string ↔ enum
/// mapping happens here, once.
pub(crate) trait Options: Copy + PartialEq + 'static {
    const ALL: &'static [Self];
    fn label(self) -> &'static str;
}

pub(crate) struct ChoiceDef<E: Options> {
    pub name: &'static str,
    pub label: &'static str,
    pub default: E,
    pub brush: Option<Brush>,
}

pub(crate) struct Choice<E: Options> {
    def: &'static ChoiceDef<E>,
    inner: ChoiceField,
}

impl<E: Options> Choice<E> {
    pub(crate) fn of(def: &'static ChoiceDef<E>) -> Self {
        let items = E::ALL.iter().map(|e| e.label().to_string()).collect();
        let mut inner = ChoiceField::new(def.name, def.label, items);
        inner.set_value(&FieldValue::Text(def.default.label().to_string()));
        Choice { def, inner }
    }

    #[allow(dead_code)]
    pub(crate) fn get(&self) -> E {
        let current = self.inner.get();
        E::ALL
            .iter()
            .copied()
            .find(|e| e.label() == current)
            .unwrap_or(self.def.default)
    }

    #[allow(dead_code)]
    pub(crate) fn set(&mut self, value: E) {
        self.inner
            .set_value(&FieldValue::Text(value.label().to_string()));
    }

    pub(crate) fn entry(&self) -> FieldRef<'_> {
        FieldRef {
            field: &self.inner,
            brush: self.def.brush,
        }
    }

    pub(crate) fn entry_mut(&mut self) -> FieldMut<'_> {
        FieldMut {
            field: &mut self.inner,
            brush: self.def.brush,
        }
    }
}

// ── Caption choice ─────────────────────────────────────────────────

/// A choice over fixed captions that are consumed as strings (the def-grid
/// filters, whose captions feed the filter predicates directly). Prefer
/// `Choice<E>` when the value is acted on as an enum.
pub(crate) struct StrChoiceDef {
    pub name: &'static str,
    pub label: &'static str,
    pub items: &'static [&'static str],
    pub brush: Option<Brush>,
}

pub(crate) struct StrChoice {
    def: &'static StrChoiceDef,
    inner: ChoiceField,
}

impl StrChoice {
    pub(crate) fn of(def: &'static StrChoiceDef) -> Self {
        let items = def.items.iter().map(|item| (*item).to_string()).collect();
        StrChoice {
            def,
            inner: ChoiceField::new(def.name, def.label, items),
        }
    }

    pub(crate) fn get(&self) -> &str {
        self.inner.get()
    }

    pub(crate) fn entry(&self) -> FieldRef<'_> {
        FieldRef {
            field: &self.inner,
            brush: self.def.brush,
        }
    }

    pub(crate) fn entry_mut(&mut self) -> FieldMut<'_> {
        FieldMut {
            field: &mut self.inner,
            brush: self.def.brush,
        }
    }
}

// ── Dynamic choice ─────────────────────────────────────────────────

/// A choice whose options come from a model at runtime (the team roster).
/// Setting new items regenerates the underlying select; the caller is expected
/// to rebuild the markup, which the roster change already forces.
pub(crate) struct DynChoiceDef {
    pub name: &'static str,
    pub label: &'static str,
    pub brush: Option<Brush>,
}

pub(crate) struct DynChoice {
    def: &'static DynChoiceDef,
    inner: ChoiceField,
}

impl DynChoice {
    pub(crate) fn of(def: &'static DynChoiceDef) -> Self {
        DynChoice {
            def,
            inner: ChoiceField::new(def.name, def.label, vec![]),
        }
    }

    pub(crate) fn set_items(&mut self, items: Vec<String>) {
        let current = self.inner.get().to_string();
        let keep = items.contains(&current);
        self.inner = ChoiceField::new(self.def.name, self.def.label, items);
        if keep {
            self.inner.set_value(&FieldValue::Text(current));
        }
    }

    pub(crate) fn get(&self) -> &str {
        self.inner.get()
    }

    pub(crate) fn entry(&self) -> FieldRef<'_> {
        FieldRef {
            field: &self.inner,
            brush: self.def.brush,
        }
    }

    pub(crate) fn entry_mut(&mut self) -> FieldMut<'_> {
        FieldMut {
            field: &mut self.inner,
            brush: self.def.brush,
        }
    }
}

// ── Asset grid ─────────────────────────────────────────────────────

/// A thumbnail grid whose selection is a field value (the brush patterns).
/// The runtime renders it, drains its clicks, and keeps the selection shown;
/// behaviors read `selected`.
pub(crate) struct AssetGridDef {
    /// The field name the selection reads as (`patternTexture`).
    pub name: &'static str,
    /// The DOM id of the grid container.
    pub container: &'static str,
    pub root: &'static str,
    pub extensions: &'static [&'static str],
    pub cell: u32,
    pub brush: Option<Brush>,
}

pub(crate) struct AssetGrid {
    def: &'static AssetGridDef,
    grid: GridView,
    selected: String,
}

impl AssetGrid {
    pub(crate) fn of(def: &'static AssetGridDef) -> Self {
        let mut grid = GridView::new(def.container, def.cell);
        grid.configure_asset_navigation(def.root, def.extensions);
        AssetGrid {
            def,
            grid,
            selected: String::new(),
        }
    }

    #[allow(dead_code)]
    pub(crate) fn selected(&self) -> Option<&str> {
        (!self.selected.is_empty()).then_some(self.selected.as_str())
    }

    pub(crate) fn container_rml(&self) -> String {
        self.grid.container_rml()
    }

    pub(crate) fn bind(
        &mut self,
        interface: &NativeInterfaceRef,
        document: u64,
    ) -> Result<(), Error> {
        self.grid.refresh_navigation(interface, document)?;
        self.render(interface, document)
    }

    /// Drain queued clicks into the selection. Returns whether it changed.
    pub(crate) fn tick(&mut self, interface: &NativeInterfaceRef, document: u64) -> bool {
        let mut changed = false;
        for id in self
            .grid
            .drain_asset_clicks(interface, document)
            .unwrap_or_default()
        {
            self.selected = id;
            changed = true;
            let _ = self.render(interface, document);
        }
        changed
    }

    pub(crate) fn entry(&self) -> FieldRef<'_> {
        FieldRef {
            field: self,
            brush: self.def.brush,
        }
    }

    pub(crate) fn entry_mut(&mut self) -> FieldMut<'_> {
        let brush = self.def.brush;
        FieldMut { field: self, brush }
    }

    fn render(&mut self, interface: &NativeInterfaceRef, document: u64) -> Result<(), Error> {
        let selected = (!self.selected.is_empty()).then_some(self.selected.clone());
        self.grid.set_selected(selected.as_deref());
        self.grid.render(interface, document)
    }
}

/// The selection is a field value; the grid itself contributes no field row.
impl Field for AssetGrid {
    fn name(&self) -> &str {
        self.def.name
    }

    fn generate_rml(&self) -> String {
        String::new()
    }

    fn bind(
        &mut self,
        _interface: &NativeInterfaceRef,
        _document: u64,
        _changes: &crate::sbc::panels::field::ChangeQueue,
        _interactions: &crate::sbc::panels::field::InteractionQueue,
    ) -> Result<(), Error> {
        Ok(())
    }

    fn read_from_dom(&mut self, _interface: &NativeInterfaceRef) -> Result<FieldValue, Error> {
        Ok(self.value())
    }

    fn write_to_dom(&self, _interface: &NativeInterfaceRef) -> Result<(), Error> {
        Ok(())
    }

    fn set_value(&mut self, value: &FieldValue) {
        if let FieldValue::Text(text) = value {
            self.selected = text.clone();
        }
    }

    fn value(&self) -> FieldValue {
        FieldValue::Text(self.selected.clone())
    }
}

// ── Table model ────────────────────────────────────────────────────

/// A model for uniform editors (Water, Sky: every field forwards to one
/// command class). Typed IDs without a named member per field; editors with
/// real per-field logic declare named members instead.
pub(crate) struct TableEntry<Id: Copy + Eq + 'static> {
    pub id: Id,
    pub field: Box<dyn Field>,
    pub brush: Option<Brush>,
}

impl<Id: Copy + Eq + 'static> TableEntry<Id> {
    pub(crate) fn new(id: Id, field: Box<dyn Field>) -> Self {
        TableEntry {
            id,
            field,
            brush: None,
        }
    }
}

pub(crate) struct TableModel<Id: Copy + Eq + 'static> {
    entries: Vec<TableEntry<Id>>,
}

impl<Id: Copy + Eq + 'static> TableModel<Id> {
    pub(crate) fn new(entries: Vec<TableEntry<Id>>) -> Self {
        TableModel { entries }
    }

    pub(crate) fn value(&self, id: Id) -> FieldValue {
        self.entries
            .iter()
            .find(|entry| entry.id == id)
            .map(|entry| entry.field.value())
            .unwrap_or(FieldValue::Text(String::new()))
    }

    pub(crate) fn set(&mut self, id: Id, value: FieldValue) {
        if let Some(entry) = self.entries.iter_mut().find(|entry| entry.id == id) {
            entry.field.set_value(&value);
        }
    }

    pub(crate) fn field_name(&self, id: Id) -> String {
        self.entries
            .iter()
            .find(|entry| entry.id == id)
            .map(|entry| entry.field.name().to_string())
            .unwrap_or_default()
    }
}

impl<Id: Copy + Eq + 'static> crate::sbc::panels::runtime::contract::EditorModel
    for TableModel<Id>
{
    type Id = Id;

    fn fields(&self) -> Vec<FieldRef<'_>> {
        self.entries
            .iter()
            .map(|entry| FieldRef {
                field: entry.field.as_ref(),
                brush: entry.brush,
            })
            .collect()
    }

    fn fields_mut(&mut self) -> Vec<FieldMut<'_>> {
        self.entries
            .iter_mut()
            .map(|entry| FieldMut {
                field: entry.field.as_mut(),
                brush: entry.brush,
            })
            .collect()
    }

    fn id_of(&self, name: &str) -> Option<Id> {
        self.entries
            .iter()
            .find(|entry| entry.field.name() == name)
            .map(|entry| entry.id)
    }

    fn name_of(&self, id: Id) -> String {
        self.field_name(id)
    }
}
