mod commands;
mod fields;
mod model;
mod rules;
mod states;

use spring_native::prelude::NativeInterfaceRef;

use super::object_handler::{ObjectHandler, ObjectHandlerFactory};
use super::object_kind::ObjectKind;

pub use model::UnitModel;

inventory::submit! {
    ObjectHandlerFactory {
        kind: ObjectKind::Unit,
        make: |iface: NativeInterfaceRef| Box::new(UnitModel::new(iface)) as Box<dyn ObjectHandler>,
    }
}
