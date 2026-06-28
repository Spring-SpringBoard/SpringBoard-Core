mod fields;
mod model;
mod rules;

use spring_native::prelude::NativeInterfaceRef;

use super::object_handler::{ObjectHandler, ObjectHandlerFactory};
use super::object_kind::ObjectKind;

pub use model::FeatureModel;

inventory::submit! {
    ObjectHandlerFactory {
        kind: ObjectKind::Feature,
        make: |iface: NativeInterfaceRef| Box::new(FeatureModel::new(iface)) as Box<dyn ObjectHandler>,
    }
}
