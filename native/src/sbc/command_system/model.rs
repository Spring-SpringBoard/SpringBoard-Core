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
    /// The concrete type's name, for diagnostics. The default resolves to the
    /// implementing type through the vtable; do not override.
    fn type_name(&self) -> &'static str {
        std::any::type_name::<Self>()
    }
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
        let mut map: HashMap<TypeId, Box<dyn Model>> = HashMap::new();
        for factory in inventory::iter::<ModelFactory> {
            let model = (factory.make)(interface);
            let name = model.type_name();
            if map.insert((*model).type_id(), model).is_some() {
                panic!("duplicate model registration for {name}");
            }
        }
        Models { map }
    }

    pub fn get<T: Model>(&mut self) -> &mut T {
        self.map
            .get_mut(&TypeId::of::<T>())
            .and_then(|m| m.as_any_mut().downcast_mut::<T>())
            .expect("model not registered")
    }

    /// Run `f` with exclusive access to model `T` *and* the rest of the
    /// registry. `T` is lifted out for the call, so a model that drives the UI
    /// can read the project models it renders (the borrow checker will not let
    /// it hold two `&mut` into the same map).
    pub fn with<T: Model, R>(&mut self, f: impl FnOnce(&mut T, &mut Models) -> R) -> R {
        let mut boxed = self
            .map
            .remove(&TypeId::of::<T>())
            .expect("model not registered");
        let result = {
            let model = boxed
                .as_any_mut()
                .downcast_mut::<T>()
                .expect("model registered under the wrong type");
            f(model, self)
        };
        self.map.insert(TypeId::of::<T>(), boxed);
        result
    }

    pub fn on_history_events(&mut self, events: &[HistoryEvent]) {
        for model in self.map.values_mut() {
            model.on_history_events(events);
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    struct Widget;
    impl Model for Widget {
        fn as_any_mut(&mut self) -> &mut dyn Any {
            self
        }
    }

    /// The default `type_name` must resolve to the concrete type through the
    /// trait object — that is what the duplicate-registration panic reports.
    #[test]
    fn type_name_resolves_the_concrete_type_through_dyn_model() {
        let model: Box<dyn Model> = Box::new(Widget);
        assert!(model.type_name().ends_with("Widget"));
    }
}
