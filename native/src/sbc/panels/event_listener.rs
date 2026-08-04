//! Panel registrations at the native-module boundary.

use spring_native::prelude::Error;

use super::manager::PanelManager;
use crate::sbc::command_system::command::Command;
use crate::sbc::command_system::model::Models;
use crate::sbc::events::{Event, EventListener, EventListenerFactory, ListenerId};
use crate::sbc::keys::KeyMods;

inventory::submit! { EventListenerFactory { make: |_| Box::new(PanelEvents) } }

struct PanelEvents;

impl EventListener for PanelEvents {
    fn id(&self) -> ListenerId {
        ListenerId::Panel
    }

    fn handles(&self, event: Event) -> bool {
        matches!(
            event,
            Event::DrawScreen
                | Event::KeyPress
                | Event::KeyRelease
                | Event::TextInput
                | Event::MouseMove
                | Event::MousePress
                | Event::MouseRelease
                | Event::MouseWheel
        )
    }

    fn update(&mut self, models: &mut Models) -> Result<(), Error> {
        models.with::<PanelManager, _>(|panel, models| panel.update(models))
    }

    fn draw_screen(&mut self, models: &mut Models) -> Result<(), Error> {
        models.get::<PanelManager>().draw_screen()
    }

    fn key_press(
        &mut self,
        models: &mut Models,
        key: i32,
        scan: i32,
        repeat: bool,
        mods: KeyMods,
    ) -> Result<bool, Error> {
        models
            .get::<PanelManager>()
            .key_press(key, scan, repeat, mods)
    }

    fn key_release(
        &mut self,
        models: &mut Models,
        key: i32,
        scan: i32,
        _mods: KeyMods,
    ) -> Result<bool, Error> {
        models.get::<PanelManager>().key_release(key, scan)
    }

    fn text_input(&mut self, models: &mut Models, utf8: &str) -> Result<bool, Error> {
        models.get::<PanelManager>().text_input(utf8)
    }

    fn mouse_move(
        &mut self,
        models: &mut Models,
        x: i32,
        y: i32,
        dx: i32,
        dy: i32,
        button: i32,
    ) -> Result<bool, Error> {
        models
            .get::<PanelManager>()
            .mouse_move(x, y, dx, dy, button)
    }

    fn mouse_press(
        &mut self,
        models: &mut Models,
        x: i32,
        y: i32,
        button: i32,
    ) -> Result<bool, Error> {
        models.get::<PanelManager>().mouse_press(x, y, button)
    }

    fn mouse_release(
        &mut self,
        models: &mut Models,
        x: i32,
        y: i32,
        button: i32,
    ) -> Result<(), Error> {
        models.get::<PanelManager>().mouse_release(x, y, button)
    }

    fn mouse_wheel(&mut self, models: &mut Models, up: bool, value: f32) -> Result<bool, Error> {
        models.get::<PanelManager>().mouse_wheel(up, value)
    }

    fn drain_commands(&mut self, models: &mut Models) -> Vec<Box<dyn Command>> {
        models.get::<PanelManager>().drain_commands()
    }
}
