//! Chonsole's registrations at the native-module boundary.

use spring_native::prelude::Error;

use super::model::ChonsoleManager;
use crate::sbc::command_system::model::Models;
use crate::sbc::events::{Event, EventListener, EventListenerFactory, ListenerId};
use crate::sbc::keys::KeyMods;

inventory::submit! { EventListenerFactory { make: |_| Box::new(ChonsoleTextEvents) } }
inventory::submit! { EventListenerFactory { make: |_| Box::new(ChonsoleEvents) } }

/// Text editing gets a separate listener because it intentionally precedes the
/// other native UI surfaces, while normal Chonsole key handling comes later.
struct ChonsoleTextEvents;

impl EventListener for ChonsoleTextEvents {
    fn id(&self) -> ListenerId {
        ListenerId::ChonsoleText
    }

    fn handles(&self, event: Event) -> bool {
        matches!(event, Event::KeyPress)
    }

    fn key_press(
        &mut self,
        models: &mut Models,
        key_code: i32,
        _scan_code: i32,
        _is_repeat: bool,
        mods: KeyMods,
    ) -> Result<bool, Error> {
        models.get::<ChonsoleManager>().text_key(key_code, mods)
    }
}

struct ChonsoleEvents;

impl EventListener for ChonsoleEvents {
    fn id(&self) -> ListenerId {
        ListenerId::Chonsole
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
        models.get::<ChonsoleManager>().update()
    }

    fn draw_screen(&mut self, models: &mut Models) -> Result<(), Error> {
        models.get::<ChonsoleManager>().draw_screen()
    }

    fn key_press(
        &mut self,
        models: &mut Models,
        key_code: i32,
        scan_code: i32,
        is_repeat: bool,
        mods: KeyMods,
    ) -> Result<bool, Error> {
        models
            .get::<ChonsoleManager>()
            .key_press(key_code, scan_code, is_repeat, mods)
    }

    fn key_release(
        &mut self,
        models: &mut Models,
        key_code: i32,
        scan_code: i32,
        _mods: KeyMods,
    ) -> Result<bool, Error> {
        models
            .get::<ChonsoleManager>()
            .key_release(key_code, scan_code)
    }

    fn text_input(&mut self, models: &mut Models, utf8: &str) -> Result<bool, Error> {
        models.get::<ChonsoleManager>().text_input(utf8)
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
            .get::<ChonsoleManager>()
            .mouse_move(x, y, dx, dy, button)
    }

    fn mouse_press(
        &mut self,
        models: &mut Models,
        x: i32,
        y: i32,
        button: i32,
    ) -> Result<bool, Error> {
        models.get::<ChonsoleManager>().mouse_press(x, y, button)
    }

    fn mouse_release(
        &mut self,
        models: &mut Models,
        x: i32,
        y: i32,
        button: i32,
    ) -> Result<(), Error> {
        models.get::<ChonsoleManager>().mouse_release(x, y, button)
    }

    fn mouse_wheel(&mut self, models: &mut Models, up: bool, value: f32) -> Result<bool, Error> {
        models.get::<ChonsoleManager>().mouse_wheel(up, value)
    }
}
