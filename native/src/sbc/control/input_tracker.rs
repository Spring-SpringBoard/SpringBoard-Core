use spring_native::prelude::Error;

use crate::sbc::command_system::model::Models;
use crate::sbc::events::{Event, EventListener, EventListenerFactory, ListenerId};
use crate::sbc::keys::KeyMods;

use super::input_counter::InputCounter;

inventory::submit! { EventListenerFactory { make: |_| Box::new(InputTracker) } }

struct InputTracker;

impl InputTracker {
    fn bump(models: &mut Models) {
        models.get::<InputCounter>().bump();
    }
}

impl EventListener for InputTracker {
    fn id(&self) -> ListenerId {
        ListenerId::InputTracker
    }

    fn handles(&self, event: Event) -> bool {
        matches!(
            event,
            Event::KeyPress
                | Event::KeyRelease
                | Event::MouseMove
                | Event::MousePress
                | Event::MouseRelease
                | Event::MouseWheel
                | Event::TextInput
        )
    }

    fn key_press(
        &mut self,
        models: &mut Models,
        _key: i32,
        _scan: i32,
        _repeat: bool,
        _label: &str,
        _utf32: i32,
        _mods: KeyMods,
    ) -> Result<bool, Error> {
        Self::bump(models);
        Ok(false)
    }

    fn key_release(
        &mut self,
        models: &mut Models,
        _key: i32,
        _scan: i32,
        _label: &str,
        _utf32: i32,
        _mods: KeyMods,
    ) -> Result<bool, Error> {
        Self::bump(models);
        Ok(false)
    }

    fn mouse_move(
        &mut self,
        models: &mut Models,
        _x: i32,
        _y: i32,
        _dx: i32,
        _dy: i32,
        _button: i32,
    ) -> Result<bool, Error> {
        Self::bump(models);
        Ok(false)
    }

    fn mouse_press(
        &mut self,
        models: &mut Models,
        _x: i32,
        _y: i32,
        _button: i32,
    ) -> Result<bool, Error> {
        Self::bump(models);
        Ok(false)
    }

    fn mouse_release(
        &mut self,
        models: &mut Models,
        _x: i32,
        _y: i32,
        _button: i32,
    ) -> Result<(), Error> {
        Self::bump(models);
        Ok(())
    }

    fn mouse_wheel(&mut self, models: &mut Models, _up: bool, _value: f32) -> Result<bool, Error> {
        Self::bump(models);
        Ok(false)
    }

    fn text_input(&mut self, models: &mut Models, _utf8: &str) -> Result<bool, Error> {
        Self::bump(models);
        Ok(false)
    }
}
