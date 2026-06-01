//! Background IO worker — public surface. Design: docs/design/async-io.md.

pub use super::worker::IoWorker;

use crate::sbc::sbc::SBC;

/// A unit of background work, run on the worker thread. `Send` + owns its data,
/// so it has no engine handle (the worker can't reach the engine by construction).
pub trait IoJob: Send {
    fn run(self: Box<Self>) -> Box<dyn IoOutcome>;
}

/// A job's result, applied on the engine thread where engine calls are valid.
pub trait IoOutcome: Send {
    fn apply(self: Box<Self>, sbc: &mut SBC);
}
