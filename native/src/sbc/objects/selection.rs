//! The editor's object selection, a port of `scen_edit/model/selection_manager.lua`.
//!
//! Selection is keyed by `ObjectKind` and holds modelIDs, not springIDs, so it
//! survives an object being destroyed and recreated (undo/redo). Selecting units
//! also mirrors into the engine's own selection, so the usual selection glow
//! shows up.

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
    /// Bumped on every change, so a view knows to refresh from the new selection.
    revision: u64,
}

impl Model for SelectionManager {
    fn as_any_mut(&mut self) -> &mut dyn Any {
        self
    }
    fn on_history_events(&mut self, _events: &[HistoryEvent]) {}
}

impl SelectionManager {
    fn set_for(&mut self, kind: ObjectKind) -> &mut BTreeSet<i32> {
        match kind {
            ObjectKind::Unit => &mut self.units,
            ObjectKind::Feature => &mut self.features,
            ObjectKind::Area => &mut self.areas,
        }
    }

    pub(crate) fn get(&self, kind: ObjectKind) -> Vec<i32> {
        match kind {
            ObjectKind::Unit => self.units.iter().copied().collect(),
            ObjectKind::Feature => self.features.iter().copied().collect(),
            ObjectKind::Area => self.areas.iter().copied().collect(),
        }
    }

    pub(crate) fn count(&self) -> usize {
        self.units.len() + self.features.len() + self.areas.len()
    }

    pub(crate) fn revision(&self) -> u64 {
        self.revision
    }

    /// The first selected object, in unit → feature → area order. Views that
    /// edit one object (Properties, Collision) act on this.
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

    pub(crate) fn clear(&mut self) {
        if self.count() == 0 {
            return;
        }
        self.units.clear();
        self.features.clear();
        self.areas.clear();
        self.revision += 1;
    }

    /// Replace the selection with a single object.
    pub(crate) fn select_one(&mut self, kind: ObjectKind, model_id: i32) {
        self.units.clear();
        self.features.clear();
        self.areas.clear();
        self.set_for(kind).insert(model_id);
        self.revision += 1;
    }

    /// Toggle one object's membership, keeping the rest (shift-click).
    pub(crate) fn toggle(&mut self, kind: ObjectKind, model_id: i32) {
        let set = self.set_for(kind);
        if !set.remove(&model_id) {
            set.insert(model_id);
        }
        self.revision += 1;
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn select_one_replaces_across_kinds() {
        let mut sel = SelectionManager::default();
        sel.select_one(ObjectKind::Unit, 1);
        sel.select_one(ObjectKind::Feature, 2);
        assert_eq!(sel.get(ObjectKind::Unit), Vec::<i32>::new());
        assert_eq!(sel.get(ObjectKind::Feature), vec![2]);
        assert_eq!(sel.count(), 1);
    }

    #[test]
    fn toggle_adds_and_removes_keeping_others() {
        let mut sel = SelectionManager::default();
        sel.select_one(ObjectKind::Unit, 1);
        sel.toggle(ObjectKind::Unit, 2);
        assert_eq!(sel.get(ObjectKind::Unit), vec![1, 2]);
        sel.toggle(ObjectKind::Unit, 1);
        assert_eq!(sel.get(ObjectKind::Unit), vec![2]);
    }

    #[test]
    fn primary_prefers_units_then_features() {
        let mut sel = SelectionManager::default();
        sel.toggle(ObjectKind::Feature, 5);
        sel.toggle(ObjectKind::Unit, 3);
        assert_eq!(sel.primary(), Some((ObjectKind::Unit, 3)));
    }

    #[test]
    fn revision_moves_only_on_change() {
        let mut sel = SelectionManager::default();
        let start = sel.revision();
        sel.clear();
        assert_eq!(
            sel.revision(),
            start,
            "clearing an empty selection is a no-op"
        );
        sel.select_one(ObjectKind::Unit, 1);
        assert!(sel.revision() > start);
    }
}
