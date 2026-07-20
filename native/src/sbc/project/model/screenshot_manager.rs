use std::any::Any;
use std::path::PathBuf;

use crate::sbc::command_system::model::{Model, ModelFactory};

inventory::submit! { ModelFactory { make: |_iface| Box::new(ScreenshotManager::default()) } }

/// Carries a requested project screenshot from the save command (sim phase) to
/// the draw phase, where the framebuffer can actually be read. A save asks for
/// one; the next `DrawScreen` grabs the map and writes it, then clears the
/// request. Mirrors Lua's `SB.RequestScreenshotPath` consumed in `PerformDraw`.
#[derive(Default)]
pub(crate) struct ScreenshotManager {
    pending: Option<PathBuf>,
}

impl Model for ScreenshotManager {
    fn as_any_mut(&mut self) -> &mut dyn Any {
        self
    }
}

impl ScreenshotManager {
    pub(crate) fn request(&mut self, path: PathBuf) {
        self.pending = Some(path);
    }

    pub(crate) fn take(&mut self) -> Option<PathBuf> {
        self.pending.take()
    }
}
