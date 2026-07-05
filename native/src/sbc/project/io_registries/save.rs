use std::path::Path;

use crate::sbc::command_system::context::Context;
use crate::sbc::project::model::paths::ProjectPaths;

pub(crate) struct ProjectSaveRegistration {
    pub save: fn(&mut Context, &ProjectPaths, bool),
}

pub(crate) fn save_project(ctx: &mut Context, project_path: &Path, is_new_project: bool) {
    let paths = ProjectPaths::new(project_path);
    for registration in inventory::iter::<ProjectSaveRegistration> {
        (registration.save)(ctx, &paths, is_new_project);
    }
}

inventory::collect!(ProjectSaveRegistration);
