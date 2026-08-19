use spring_native::prelude::Error;

use super::model::screenshot_manager::ScreenshotManager;
use crate::sbc::command_system::model::Models;
use crate::sbc::events::{Event, EventListener, EventListenerFactory, ListenerId};

inventory::submit! { EventListenerFactory { make: |_| Box::new(ScreenshotEvents) } }

struct ScreenshotEvents;

impl EventListener for ScreenshotEvents {
    fn id(&self) -> ListenerId {
        ListenerId::Screenshot
    }

    fn handles(&self, event: Event) -> bool {
        matches!(event, Event::DrawScreenPost)
    }

    fn draw_screen_post(
        &mut self,
        models: &mut Models,
        _view_size_x: i32,
        _view_size_y: i32,
    ) -> Result<(), Error> {
        models.get::<ScreenshotManager>().capture_if_pending()
    }
}
