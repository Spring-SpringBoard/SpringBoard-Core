use spring_native::prelude::NativeInterfaceRef;

use crate::sbc::command_system::command::Command;
use crate::sbc::command_system::model::Models;
use crate::sbc::panels::field::FieldValue;
use crate::sbc::panels::runtime::{Behavior, Event, Item, Outcome, TableModel};
use crate::sbc::project::commands::SetScenarioInfoCommand;
use crate::sbc::project::ScenarioInfoManager;

use super::layout;
use super::model::InfoField;
use super::model::InfoField::*;

/// Project metadata. Unlike the Env views this reads the project model, not the
/// engine, and sends the whole record: `SetScenarioInfoCommand` merges a partial
/// patch, but Lua sends all four fields together.
pub(crate) struct InfoBehavior;

fn text(model: &TableModel<InfoField>, id: InfoField) -> String {
    match model.value(id) {
        FieldValue::Text(t) => t,
        _ => String::new(),
    }
}

impl Behavior for InfoBehavior {
    type Model = TableModel<InfoField>;

    fn layout(&self, _model: &Self::Model) -> Vec<Item<InfoField>> {
        layout::layout()
    }

    fn refresh(
        &mut self,
        model: &mut Self::Model,
        _engine: &NativeInterfaceRef,
        models: &mut Models,
    ) {
        let info = models.get::<ScenarioInfoManager>().serialize();
        model.set(Name, FieldValue::Text(info.name));
        model.set(Description, FieldValue::Text(info.description));
        model.set(Version, FieldValue::Text(info.version));
        model.set(Author, FieldValue::Text(info.author));
    }

    fn apply(
        &mut self,
        _event: Event<InfoField>,
        model: &mut Self::Model,
        _engine: &NativeInterfaceRef,
    ) -> Outcome {
        let data = serde_json::json!({
            "name": text(model, Name),
            "description": text(model, Description),
            "version": text(model, Version),
            "author": text(model, Author),
        });
        match SetScenarioInfoCommand::from_data(data) {
            Some(c) => Outcome::commands(vec![Box::new(c) as Box<dyn Command>]),
            None => Outcome::default(),
        }
    }
}
