//! Reusable input, history, and value types.
//!
//! The rest of Chonsole talks to this layer through these re-exports; its
//! implementation modules intentionally remain private.

mod history;
mod text_input;
mod types;

pub(super) use history::{HistoryStore, MAX_HISTORY};
pub(super) use text_input::TextInput;
pub(super) use types::{ChonsoleLine, ChonsoleLineKind, ChonsoleResponse, ChonsoleSuggestion};
