//! A modal form backed by the same runtime as every editor.
//!
//! Dialogs declare fields and layout only. Binding, click-to-edit, dragging,
//! DOM reads/writes, and value storage remain owned by `Runtime` and the panel's
//! shared input/session pipeline.

use spring_native::prelude::{Error, NativeInterfaceRef};

use crate::sbc::command_system::model::Models;
use crate::sbc::panels::editor::Editor;
use crate::sbc::panels::field::{ChangeQueue, Field, FieldValue, InteractionQueue};
use crate::sbc::panels::runtime::{
    Behavior, Event, Item, Outcome, Runtime, TableEntry, TableModel,
};

pub(crate) enum FormItem<Id> {
    Field(Id),
    IdentifiedField(Id),
    IdentifiedRow(Vec<Id>),
}

struct FormBehavior<Id> {
    layout: Vec<FormItem<Id>>,
}

impl<Id: Copy + Eq + 'static> Behavior for FormBehavior<Id> {
    type Model = TableModel<Id>;

    fn layout(&self, _model: &Self::Model) -> Vec<Item<Id>> {
        self.layout
            .iter()
            .map(|item| match item {
                FormItem::Field(id) => Item::Field(*id),
                FormItem::IdentifiedField(id) => Item::IdField(*id),
                FormItem::IdentifiedRow(ids) => Item::OwnedIdRow(ids.clone()),
            })
            .collect()
    }

    fn refresh(
        &mut self,
        _model: &mut Self::Model,
        _engine: &NativeInterfaceRef,
        _models: &mut Models,
    ) {
    }

    fn apply(
        &mut self,
        _event: Event<Id>,
        _model: &mut Self::Model,
        _engine: &NativeInterfaceRef,
    ) -> Outcome {
        Outcome::default()
    }
}

pub(crate) struct DialogForm<Id: Copy + Eq + 'static> {
    runtime: Runtime<FormBehavior<Id>>,
}

impl<Id: Copy + Eq + 'static> DialogForm<Id> {
    pub(crate) fn new(fields: Vec<(Id, Box<dyn Field>)>, layout: Vec<FormItem<Id>>) -> Self {
        let entries = fields
            .into_iter()
            .map(|(id, field)| TableEntry::new(id, field))
            .collect();
        Self {
            runtime: Runtime::new(FormBehavior { layout }, TableModel::new(entries)),
        }
    }

    pub(crate) fn markup(&self) -> String {
        self.runtime.generate_rml()
    }

    pub(crate) fn bind(
        &mut self,
        interface: &NativeInterfaceRef,
        document: u64,
        changes: &ChangeQueue,
        interactions: &InteractionQueue,
    ) -> Result<(), Error> {
        self.runtime
            .bind_fields(interface, document, changes, interactions)
    }

    pub(crate) fn set(&mut self, id: Id, value: FieldValue) {
        self.runtime.model_mut().set(id, value);
    }

    pub(crate) fn value(&self, id: Id) -> FieldValue {
        self.runtime.model().value(id)
    }

    pub(crate) fn write(&self, interface: &NativeInterfaceRef) -> Result<(), Error> {
        self.runtime.write_field_values(interface)
    }

    pub(crate) fn commit(&mut self, id: Id, interface: &NativeInterfaceRef) {
        let name = self.runtime.model().field_name(id);
        self.runtime.process_change(&name, interface);
    }

    pub(crate) fn editor(&self) -> &dyn Editor {
        &self.runtime
    }

    pub(crate) fn editor_mut(&mut self) -> &mut dyn Editor {
        &mut self.runtime
    }
}
