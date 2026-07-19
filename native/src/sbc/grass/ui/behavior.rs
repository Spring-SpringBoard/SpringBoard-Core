use spring_native::prelude::NativeInterfaceRef;

use crate::sbc::command_system::model::Models;
use crate::sbc::panels::brush::BrushAction;
use crate::sbc::panels::runtime::{Behavior, Event, Item, Outcome, Phase, Watch};

use super::layout;
use super::model::{GrassField, GrassModel};

pub(crate) struct GrassBehavior;

impl Behavior for GrassBehavior {
    type Model = GrassModel;

    fn actions(&self) -> Option<&'static [BrushAction]> {
        Some(layout::ACTIONS)
    }

    fn layout(&self, _model: &GrassModel) -> Vec<Item<GrassField>> {
        layout::layout()
    }

    fn refresh(
        &mut self,
        model: &mut GrassModel,
        engine: &NativeInterfaceRef,
        _models: &mut Models,
    ) {
        if let Ok((detail, true)) = engine.config().get_config_int("GrassDetail", Some(5)) {
            model.detail.set(detail as f32);
        }
    }

    /// The config write happens on commit (Enter, or drag release); one per
    /// drag step would be wasteful.
    fn apply(
        &mut self,
        event: Event<GrassField>,
        model: &mut GrassModel,
        engine: &NativeInterfaceRef,
    ) -> Outcome {
        if let Event::Changed(GrassField::Detail, Phase::Commit) = event {
            let detail = model.detail.get().ceil() as i32;
            let _ = engine.config().set_config_int("GrassDetail", detail, true);
        }
        Outcome::default()
    }

    fn watch(&mut self, _model: &mut GrassModel, _models: &mut Models) -> Watch {
        Watch::Unchanged
    }
}
