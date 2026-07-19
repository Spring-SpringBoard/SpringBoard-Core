//! Shared body of the Objects tab's Units and Features views.
//!
//! A view is: Add / Brush mode buttons, a team + placement fields, a search box,
//! and a grid of definitions. Selecting a definition (or changing a setting
//! while one is selected) arms the map click to place it.
//!
//! Not ported: for units the **type/terrain filters** need unit-def category
//! bindings that are not exposed. Build pictures are deliberately not used as a
//! thumbnail substitute — many games have none.

mod behavior;
mod layout;
mod model;

pub(crate) use behavior::ObjectDefsBehavior;
pub(crate) use model::{DefKind, ObjectDefsModel};
