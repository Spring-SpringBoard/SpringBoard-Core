//! The editor's mouse-driven editing states: what a click on the map does.

pub(crate) mod brush_settings;
mod cursor;
pub(crate) mod highlight;
mod manager;
mod manipulate;
mod map_editing;
mod rectangle_select;
pub(crate) mod shapes;
pub(crate) mod state;

pub(crate) use crate::sbc::objects::PlacementConfig;
pub(crate) use brush_settings::{ApplyDir, BrushSettings};
pub(crate) use manager::{StateManager, StateRequest};
pub(crate) use map_editing::{BrushButton, BrushStamp, MapBrush};
pub(crate) use state::{cursor, trace_ground};
