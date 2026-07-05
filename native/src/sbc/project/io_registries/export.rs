use std::path::Path;

use crate::sbc::command_system::context::Context;

pub(crate) struct MapExportRegistration {
    pub export: fn(&mut Context, &Path, &MapExportOptions),
}

pub(crate) struct MapExportOptions {
    pub heightmap_extremes: Option<Vec<f32>>,
}

pub(crate) fn export_maps(ctx: &mut Context, output_dir: &Path, options: &MapExportOptions) {
    for registration in inventory::iter::<MapExportRegistration> {
        (registration.export)(ctx, output_dir, options);
    }
}

inventory::collect!(MapExportRegistration);
