//! The editor's mouse-driven editing states: what a click on the map does.

mod add_object;
pub(crate) mod brush_settings;
mod manager;
mod map_editing;
mod shapes;
mod state;

pub(crate) use brush_settings::{ApplyDir, BrushSettings};
pub(crate) use manager::{StateManager, StateRequest};
pub(crate) use map_editing::BrushKind;
