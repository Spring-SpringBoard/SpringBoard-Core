pub(crate) mod commands;
pub(crate) mod io_registries;
pub(crate) mod jobs;
pub(crate) mod model;
pub(crate) mod new_project_dialog;
pub(crate) mod ops;
pub(crate) mod paths;
pub(crate) mod status_bar;
mod tests;
mod ui;

pub(crate) use model::project_manager::{ProjectData, ProjectManager};
pub(crate) use model::scenario_info_manager::{ScenarioInfo, ScenarioInfoManager};
pub(crate) use model::screenshot_manager::ScreenshotManager;
pub(crate) use status_bar::ProjectStatusBar;
