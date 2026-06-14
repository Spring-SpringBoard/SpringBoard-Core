use std::any::{Any, TypeId};
use std::collections::HashMap;

use spring_native::prelude::NativeInterfaceRef;

use super::history::HistoryEvent;

/// A domain model owned by the command system. Each feature implements this for
/// its model so the command system can store, hand out, and fan out to them
/// without naming any domain type.
pub trait Model: Any {
    fn as_any_mut(&mut self) -> &mut dyn Any;
    /// React to command-history changes (default: ignore).
    fn on_history_events(&mut self, _events: &[HistoryEvent]) {}
}

/// Self-registration hook: a feature submits one factory per model.
pub struct ModelFactory {
    pub make: fn(NativeInterfaceRef) -> Box<dyn Model>,
}
inventory::collect!(ModelFactory);

/// Type-keyed set of the registered domain models.
#[derive(Default)]
pub struct Models {
    map: HashMap<TypeId, Box<dyn Model>>,
}

impl Models {
    pub fn build(interface: NativeInterfaceRef) -> Self {
        let mut map = HashMap::new();
        for factory in inventory::iter::<ModelFactory> {
            let model = (factory.make)(interface);
            map.insert((*model).type_id(), model);
        }
        Models { map }
    }

    pub fn get<T: Model>(&mut self) -> &mut T {
        self.map
            .get_mut(&TypeId::of::<T>())
            .and_then(|m| m.as_any_mut().downcast_mut::<T>())
            .expect("model not registered")
    }

    pub fn on_history_events(&mut self, events: &[HistoryEvent]) {
        for model in self.map.values_mut() {
            model.on_history_events(events);
        }
    }
}
