//! Chonsole's RmlUi presentation boundary.

mod controller;
mod events;
mod view;
mod view_render;
mod view_rml;
mod view_suggestions;

pub(super) use controller::{ChonsoleController, UiKeyOutcome};
