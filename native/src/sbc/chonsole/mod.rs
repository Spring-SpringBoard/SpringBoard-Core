mod commands;
mod framework;
mod integration;
mod model;
mod tests;
mod ui;

/// Chonsole's sole crate-wide integration seam.
pub(crate) use model::ChonsoleManager;
