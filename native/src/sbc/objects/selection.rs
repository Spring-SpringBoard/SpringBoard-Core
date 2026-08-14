use std::any::Any;
use std::collections::BTreeSet;

use crate::sbc::command_system::history::HistoryEvent;
use crate::sbc::command_system::model::{Model, ModelFactory};
use crate::sbc::objects::ObjectKind;

inventory::submit! {
    ModelFactory { make: |_| Box::new(SelectionManager::default()) }
}

#[derive(Default)]
pub(crate) struct SelectionManager {
    units: BTreeSet<i32>,
    features: BTreeSet<i32>,
    areas: BTreeSet<i32>,
}

impl Model for SelectionManager {
    fn as_any_mut(&mut self) -> &mut dyn Any {
        self
    }
    fn on_history_events(&mut self, _events: &[HistoryEvent]) {}
}

impl SelectionManager {
    pub(crate) fn count(&self) -> usize {
        self.units.len() + self.features.len() + self.areas.len()
    }

    pub(crate) fn primary(&self) -> Option<(ObjectKind, i32)> {
        for kind in [ObjectKind::Unit, ObjectKind::Feature, ObjectKind::Area] {
            if let Some(&id) = self.set_ref(kind).iter().next() {
                return Some((kind, id));
            }
        }
        None
    }

    fn set_ref(&self, kind: ObjectKind) -> &BTreeSet<i32> {
        match kind {
            ObjectKind::Unit => &self.units,
            ObjectKind::Feature => &self.features,
            ObjectKind::Area => &self.areas,
        }
    }
}
