use std::any::Any;

use super::field_descriptor::ObjectFieldDescriptor;

/// One object field, defined with its value type as a real generic. Implementors
/// read and write the engine (or editor state) in typed values. The erasure that
/// lets fields of different value types share one registry lives in
/// [`FieldEntry`], not here.
pub trait TypedField<S>: 'static {
    type Value: 'static;
    const DESCRIPTOR: ObjectFieldDescriptor;

    fn get(state: &S, id: i32) -> Option<Self::Value>;
    fn set(state: &mut S, id: i32, value: &Self::Value);
}

/// A type-erased field: the single concrete type each object kind collects with
/// `inventory`. The box always holds this field's `Value` (the same entry both
/// reads and applies it), so the downcast can't miss.
pub struct FieldEntry<S: 'static> {
    pub descriptor: ObjectFieldDescriptor,
    pub set: fn(&mut S, i32, &dyn Any),
    pub get: fn(&S, i32) -> Option<Box<dyn Any>>,
}

impl<S: 'static> FieldEntry<S> {
    /// Erase a [`TypedField`] into a registrable entry. The members are generic
    /// free functions coerced to plain fn pointers, so this stays `const` and
    /// captures nothing — exactly what `inventory::submit!` needs.
    pub const fn of<F: TypedField<S>>() -> Self {
        FieldEntry {
            descriptor: F::DESCRIPTOR,
            set: erased_set::<S, F>,
            get: erased_get::<S, F>,
        }
    }
}

fn erased_set<S, F: TypedField<S>>(state: &mut S, id: i32, value: &dyn Any) {
    match value.downcast_ref::<F::Value>() {
        Some(value) => F::set(state, id, value),
        // Only reachable if a field is dispatched a value it did not produce.
        None => log::error!(
            "objects: field {} got the wrong value type",
            F::DESCRIPTOR.name
        ),
    }
}

fn erased_get<S, F: TypedField<S>>(state: &S, id: i32) -> Option<Box<dyn Any>> {
    Some(Box::new(F::get(state, id)?) as Box<dyn Any>)
}
