mod fields;
mod model;

use spring_native::prelude::NativeInterfaceRef;

use super::object_handler::{ObjectHandler, ObjectHandlerFactory};
use super::object_kind::ObjectKind;

pub use model::AreaModel;

inventory::submit! {
    ObjectHandlerFactory {
        kind: ObjectKind::Area,
        make: |_iface: NativeInterfaceRef| Box::new(AreaModel::new()) as Box<dyn ObjectHandler>,
    }
}
