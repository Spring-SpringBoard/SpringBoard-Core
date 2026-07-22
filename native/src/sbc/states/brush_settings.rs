//! The brush the Map tab's editors configure and its states consume.
//!
//! Lua reads the editor's fields when it enters a state and writes back to them
//! on a mouse wheel. Both sides here talk to this model instead, so a wheel that
//! resizes the brush shows up in the panel and a field edit reaches the brush.

use std::any::Any;
use std::collections::BTreeMap;

use serde::{Deserialize, Serialize};

use crate::sbc::command_system::history::HistoryEvent;
use crate::sbc::command_system::model::{Model, ModelFactory};

inventory::submit! {
    ModelFactory { make: |_| Box::new(BrushSettings::default()) }
}

/// Which way a level brush is allowed to move the terrain.
#[derive(Debug, Clone, Copy, Default, PartialEq, Eq, Serialize, Deserialize)]
pub(crate) enum ApplyDir {
    #[default]
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

    pub(crate) fn caption(self) -> &'static str {
        match self {
            ApplyDir::Both => "Both",
            ApplyDir::OnlyRaise => "Only Raise",
            ApplyDir::OnlyLower => "Only Lower",
        }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(default, rename_all = "camelCase")]
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
    pub brush_textures: BTreeMap<String, String>,
    pub texture_enabled: BTreeMap<String, bool>,
    pub texture_paint_mode: String,
    pub kernel_mode: String,
    pub exclusive: bool,
    pub void_factor: f32,
    pub color_index: i32,
    pub mode: String,
    pub tex_scale: f32,
    /// How the material itself is sampled, independent of the brush pattern.
    pub tex_rotation: f32,
    pub tex_offset_x: f32,
    pub tex_offset_y: f32,
    pub falloff_factor: f32,
    pub feature_factor: f32,
    pub diffuse_color: [f32; 4],
    /// The level a DNTS channel is painted towards.
    pub value: f32,
    pub splat_tex_scale: f32,
    pub splat_tex_mult: f32,
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
            brush_textures: BTreeMap::new(),
            texture_enabled: BTreeMap::new(),
            texture_paint_mode: "paint".to_string(),
            kernel_mode: "blur".to_string(),
            exclusive: false,
            void_factor: 1.0,
            color_index: 1,
            mode: "Normal".to_string(),
            tex_scale: 2.0,
            tex_rotation: 0.0,
            tex_offset_x: 0.0,
            tex_offset_y: 0.0,
            falloff_factor: 0.3,
            feature_factor: 1.0,
            diffuse_color: [1.0, 1.0, 1.0, 1.0],
            value: 1.0,
            splat_tex_scale: 1.0,
            splat_tex_mult: 0.5,
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
