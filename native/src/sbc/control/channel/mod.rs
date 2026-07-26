//! The transport: the socket, the discovery file that advertises it, the
//! JSON-RPC envelope, and the replies still waiting on an effect to land.

mod discovery;
mod pending;
pub(super) mod protocol;
mod server;

pub(super) use pending::{Effect, Pending};
pub(super) use protocol::Request;
pub(crate) use server::ControlServer;
