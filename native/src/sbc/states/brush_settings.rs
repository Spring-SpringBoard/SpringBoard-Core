//! The brush the Map tab's editors configure and its states consume.
//!
//! Lua reads the editor's fields when it enters a state and writes back to them
//! on a mouse wheel. Both sides here talk to this model instead, so a wheel that
//! resizes the brush shows up in the panel and a field edit reaches the brush.

use std::any::Any;

use crate::sbc::command_system::history::HistoryEvent;
use crate::sbc::command_system::model::{Model, ModelFactory};

inventory::submit! {
    ModelFactory { make: |_| Box::new(BrushSettings::default()) }
}

/// Which way a level brush is allowed to move the terrain.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub(crate) enum ApplyDir {
    Both,
    OnlyRaise,
    OnlyLower,
}

impl ApplyDir {
    pub(crate) fn from_caption(caption: &str) -> ApplyDir {
        match caption {
            "Only Raise" => ApplyDir::OnlyRaise,
            "Only Lower" => ApplyDir::OnlyLower,
            _ => ApplyDir::Both,
        }
    }

    /// The `applyDirID` `TerrainLevelCommand` expects.
    pub(crate) fn id(self) -> i32 {
        match self {
            ApplyDir::Both => 0,
            ApplyDir::OnlyRaise => 1,
            ApplyDir::OnlyLower => -1,
        }
    }
}

#[derive(Debug, Clone)]
pub(crate) struct BrushSettings {
    pub size: f32,
    pub rotation: f32,
    pub strength: f32,
    pub height: f32,
    pub amount: f32,
    pub apply_dir: ApplyDir,
    pub pattern_texture: Option<String>,
    /// Texture brush only.
    pub brush_texture: Option<String>,
    pub mode: String,
    pub tex_scale: f32,
    /// Bumped whenever a state changes a value, so the open editor refreshes.
    pub revision: u64,
}

impl Default for BrushSettings {
    fn default() -> Self {
        BrushSettings {
            size: 100.0,
            rotation: 0.0,
            strength: 10.0,
            height: 10.0,
            amount: 50.0,
            apply_dir: ApplyDir::Both,
            pattern_texture: None,
            brush_texture: None,
            mode: "Normal".to_string(),
            tex_scale: 2.0,
            revision: 0,
        }
    }
}

impl Model for BrushSettings {
    fn as_any_mut(&mut self) -> &mut dyn Any {
        self
    }
    fn on_history_events(&mut self, _events: &[HistoryEvent]) {}
}

impl BrushSettings {
    /// Mouse-wheel resize, matching `AbstractMapEditingState:MouseWheel`.
    pub(crate) fn scale_size(&mut self, up: bool) {
        self.size = if up {
            self.size + self.size * 0.2 + 2.0
        } else {
            self.size - self.size * 0.2 - 2.0
        }
        .max(1.0);
        self.revision += 1;
    }

    pub(crate) fn rotate(&mut self, up: bool) {
        self.rotation += if up { 5.0 } else { -5.0 };
        self.revision += 1;
    }

    pub(crate) fn set_height(&mut self, height: f32) {
        self.height = height;
        self.revision += 1;
    }
}
