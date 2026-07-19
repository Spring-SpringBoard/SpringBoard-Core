use spring_native::prelude::NativeInterfaceRef;

use crate::sbc::command_system::model::Models;
use crate::sbc::panels::brush::BrushAction;
use crate::sbc::panels::runtime::{Behavior, Item};

use super::layout;
use super::model::{TerrainField, TerrainModel};

pub(crate) struct TerrainBehavior;

impl Behavior for TerrainBehavior {
    type Model = TerrainModel;

    fn actions(&self) -> Option<&'static [BrushAction]> {
        Some(layout::ACTIONS)
    }

    fn layout(&self, _model: &TerrainModel) -> Vec<Item<TerrainField>> {
        layout::layout()
    }

    fn refresh(
        &mut self,
        _model: &mut TerrainModel,
        _engine: &NativeInterfaceRef,
        _models: &mut Models,
    ) {
    }
}
