use std::any::Any;

use crate::sbc::command_system::history::HistoryEvent;
use crate::sbc::command_system::model::{Model, ModelFactory};

use super::super::shader_cache::ShaderCache;
use super::cache::TextureCache;
use super::history::TextureHistory;
use super::shading::ShadingStore;
use super::tiles::TileStore;

inventory::submit! {
    ModelFactory {
        make: |interface| {
            Box::new(TextureModel {
                tiles: TileStore::new(interface),
                shading: ShadingStore::new(interface),
                cache: TextureCache::new(interface),
                shaders: ShaderCache::new(),
                history: TextureHistory::new(interface),
            })
        },
    }
}

/// The textures feature's state: independently-usable components. Behaviour
/// lives on the components; this only owns them and wires the feature into the
/// command system as a [`Model`].
pub(crate) struct TextureModel {
    pub(crate) tiles: TileStore,
    pub(crate) shading: ShadingStore,
    pub(crate) cache: TextureCache,
    pub(crate) shaders: ShaderCache,
    pub(crate) history: TextureHistory,
}

impl Model for TextureModel {
    fn as_any_mut(&mut self) -> &mut dyn Any {
        self
    }

    fn on_history_events(&mut self, events: &[HistoryEvent]) {
        self.history.on_history_events(events);
    }
}
