use std::any::Any;
use std::path::PathBuf;

use spring_native::prelude::{Error, NativeInterfaceRef};

use crate::sbc::command_system::model::{Model, ModelFactory};

inventory::submit! { ModelFactory { make: |iface| Box::new(ScreenshotManager::new(iface)) } }

pub(crate) struct ScreenshotManager {
    interface: NativeInterfaceRef,
    pending: Option<CaptureRequest>,
}

pub(crate) struct CaptureRequest {
    pub path: PathBuf,
    pub full_window: bool,
}

impl ScreenshotManager {
    fn new(interface: NativeInterfaceRef) -> Self {
        Self {
            interface,
            pending: None,
        }
    }

    pub(crate) fn request(&mut self, path: PathBuf, full_window: bool) {
        self.pending = Some(CaptureRequest { path, full_window });
    }

    pub(crate) fn capture_if_pending(&mut self) -> Result<(), Error> {
        let Some(capture) = self.pending.take() else {
            return Ok(());
        };
        let Ok(geom) = self.interface.display().get_view_geometry() else {
            return Ok(());
        };
        let width = if capture.full_window {
            geom.viewSizeX
        } else {
            const PANEL_WIDTH: i32 = 500;
            (geom.viewSizeX - PANEL_WIDTH).max(1)
        };
        if let Some(parent) = capture.path.parent() {
            let _ = std::fs::create_dir_all(parent);
        }
        let _ = self.interface.gfx().save_image(
            0,
            0,
            width,
            geom.viewSizeY,
            &capture.path.to_string_lossy(),
            spring_native::GfxSaveImageOptions {
                alpha: false,
                yflip: true,
                grayscale16bit: false,
            },
            0,
        );
        Ok(())
    }
}

impl Model for ScreenshotManager {
    fn as_any_mut(&mut self) -> &mut dyn Any {
        self
    }
}
