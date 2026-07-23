use std::any::Any;
use std::path::PathBuf;

use crate::sbc::command_system::model::{Model, ModelFactory};

inventory::submit! { ModelFactory { make: |_iface| Box::new(ScreenshotManager::default()) } }

/// Carries a requested project screenshot from the save command (sim phase) to
/// the draw phase, where the framebuffer can actually be read. A save asks for
/// one; the next `DrawScreen` grabs the map and writes it, then clears the
/// request. Mirrors Lua's `SB.RequestScreenshotPath` consumed in `PerformDraw`.
pub(crate) struct ScreenshotManager {
    pending: Option<PathBuf>,
    e2e_request: Option<PathBuf>,
    e2e_pending: Option<PathBuf>,
}

impl Default for ScreenshotManager {
    fn default() -> Self {
        Self {
            pending: None,
            e2e_request: std::env::var_os("SBC_E2E_SCREENSHOT_REQUEST").map(PathBuf::from),
            e2e_pending: None,
        }
    }
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

    pub(crate) fn take_e2e(&mut self) -> Option<PathBuf> {
        if self.e2e_pending.is_some() {
            return self.e2e_pending.take();
        }
        let request = self.e2e_request.as_ref()?;
        let path = PathBuf::from(std::fs::read_to_string(request).ok()?.trim());
        if path.as_os_str().is_empty() {
            return None;
        }
        let _ = std::fs::remove_file(request);
        self.e2e_pending = Some(path);
        None
    }
}
