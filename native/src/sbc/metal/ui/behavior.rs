use spring_native::prelude::NativeInterfaceRef;

use crate::sbc::command_system::model::Models;
use crate::sbc::panels::brush::BrushAction;
use crate::sbc::panels::runtime::{Behavior, Item};

use super::layout;
use super::model::{MetalField, MetalModel};

pub(crate) struct MetalBehavior;

impl Behavior for MetalBehavior {
    type Model = MetalModel;

    fn actions(&self) -> Option<&'static [BrushAction]> {
        Some(layout::ACTIONS)
    }

    fn layout(&self, _model: &MetalModel) -> Vec<Item<MetalField>> {
        layout::layout()
    }

    fn refresh(
        &mut self,
        _model: &mut MetalModel,
        _engine: &NativeInterfaceRef,
        _models: &mut Models,
    ) {
    }
}
