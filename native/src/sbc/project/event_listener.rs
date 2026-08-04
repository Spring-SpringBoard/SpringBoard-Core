//! Project screenshot capture at the native-module boundary.

use spring_native::prelude::{Error, NativeInterfaceRef};

use super::model::screenshot_manager::ScreenshotManager;
use crate::sbc::command_system::model::Models;
use crate::sbc::events::{Event, EventListener, EventListenerFactory, ListenerId};

inventory::submit! { EventListenerFactory { make: |interface| Box::new(ScreenshotEvents { interface }) } }

struct ScreenshotEvents {
    interface: NativeInterfaceRef,
}

impl EventListener for ScreenshotEvents {
    fn id(&self) -> ListenerId {
        ListenerId::Screenshot
    }

    fn handles(&self, event: Event) -> bool {
        matches!(event, Event::DrawScreen | Event::DrawScreenPost)
    }

    fn draw_screen(&mut self, models: &mut Models) -> Result<(), Error> {
        let Some(path) = models.get::<ScreenshotManager>().take() else {
            return Ok(());
        };
        let Ok(geom) = self.interface.display().get_view_geometry() else {
            return Ok(());
        };
        const PANEL_WIDTH: i32 = 500;
        let width = (geom.viewSizeX - PANEL_WIDTH).max(1);
        if let Some(parent) = path.parent() {
            let _ = std::fs::create_dir_all(parent);
        }
        let _ = self.interface.gfx().save_image(
            0,
            0,
            width,
            geom.viewSizeY,
            &path.to_string_lossy(),
            spring_native::GfxSaveImageOptions {
                alpha: false,
                yflip: true,
                grayscale16bit: false,
            },
            0,
        );
        Ok(())
    }

    fn draw_screen_post(&mut self, models: &mut Models) -> Result<(), Error> {
        let Some(path) = models.get::<ScreenshotManager>().take_e2e() else {
            return Ok(());
        };
        let Ok(geom) = self.interface.display().get_view_geometry() else {
            return Ok(());
        };
        let _ = self.interface.gfx().save_image(
            0,
            0,
            geom.viewSizeX,
            geom.viewSizeY,
            &path.to_string_lossy(),
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
