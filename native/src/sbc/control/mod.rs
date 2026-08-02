//! Machine-facing control channel: JSON-RPC over loopback TCP, driving the
//! editor through the same editors, commands and camera a user reaches.
//!
//! `api/` is the surface — one file per group of methods, each taking its own
//! params type and going through the seam the equivalent user action does.
//! `channel/` is the plumbing that carries them: socket, discovery file,
//! JSON-RPC shapes, deferred replies. `dispatch` is the seam between the two,
//! and the only place that knows both.

mod api;
mod channel;
mod dispatch;
mod error;
mod reply;

pub(crate) use channel::ControlServer;
pub(crate) use dispatch::{begin_update, finish_update};
pub(crate) use error::ControlError;
pub(crate) use reply::{Handled, Reply};
