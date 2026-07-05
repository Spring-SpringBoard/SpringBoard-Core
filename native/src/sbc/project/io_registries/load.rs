use std::path::Path;

use crate::sbc::command_system::context::Context;
use crate::sbc::project::model::paths::ProjectPaths;

pub(crate) struct ProjectLoadRegistration {
    pub load: fn(&mut Context, &ProjectPaths),
}

pub(crate) fn load_project(ctx: &mut Context, project_path: &Path) {
    let paths = ProjectPaths::new(project_path);
    for registration in inventory::iter::<ProjectLoadRegistration> {
        (registration.load)(ctx, &paths);
    }
}

inventory::collect!(ProjectLoadRegistration);
