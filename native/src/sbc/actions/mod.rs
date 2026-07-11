//! The action layer: the toolbar buttons and hotkeys, and the logic each one
//! runs. Ports `scen_edit/view/actions/*.lua`. An [`Action`] is pure metadata;
//! [`execute`]/[`can_execute`] are the free functions the panel manager and the
//! hotkey handler both call, so an action behaves identically however triggered.

mod action;
mod clipboard;
mod dialog;
mod helpers;
mod paths;
mod project;
mod run;

pub use action::Action;
pub use dialog::{ActionResult, FileAcceptFn, FileDialogConfig, FileDialogResult};
pub use project::{available_maps, commit_new_project};
pub use run::{can_execute, execute, execute_paste};
