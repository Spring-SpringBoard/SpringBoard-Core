//! Command catalog refresh and execution adapters.

mod catalog;
mod completion;
mod core;
mod executor;
mod registrations;
mod registry;

pub(super) use catalog::CatalogRefresher;
pub(super) use completion::ConsoleCommand;
pub(super) use core::{ChatTarget, ChonsoleAction, ChonsoleCore, ChonsoleEffect, RuleScope};
pub(super) use executor::CommandExecutor;
pub(super) use registry::CommandRegistry;
