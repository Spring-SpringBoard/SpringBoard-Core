//! Moving and rotating selected objects, ports of `drag_object_state.lua` and
//! `rotate_object_state.lua`.
//!
//! The object itself does not move until the button comes up: a ghost of it is
//! drawn where it would land, and the original stays put. Only the release
//! commits, as one undoable group.

mod drag;
mod ghost;
mod rotate;
mod shared;

pub(crate) use drag::DragObjectState;
pub(crate) use rotate::RotateObjectState;
