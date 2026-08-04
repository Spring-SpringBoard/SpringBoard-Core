//! Editing-state registrations at the native-module boundary.

use spring_native::prelude::Error;

use super::manager::StateManager;
use crate::sbc::command_system::command::Command;
use crate::sbc::command_system::model::Models;
use crate::sbc::events::{Event, EventListener, EventListenerFactory, ListenerId};
use crate::sbc::keys::KeyMods;

inventory::submit! { EventListenerFactory { make: |_| Box::new(StateEvents) } }

struct StateEvents;

impl EventListener for StateEvents {
    fn id(&self) -> ListenerId {
        ListenerId::State
    }

    fn handles(&self, event: Event) -> bool {
        matches!(
            event,
            Event::DrawScreen
                | Event::DrawWorld
                | Event::KeyPress
                | Event::MouseMove
                | Event::MousePress
                | Event::MouseRelease
                | Event::MouseWheel
        )
    }

    fn update(&mut self, models: &mut Models) -> Result<(), Error> {
        models.with::<StateManager, _>(|states, models| -> Result<(), Error> {
            states.sync_brush(models);
            states.update(models)
        })
    }

    fn draw_screen(&mut self, models: &mut Models) -> Result<(), Error> {
        models.get::<StateManager>().draw_screen();
        Ok(())
    }

    fn draw_world(&mut self, models: &mut Models) -> Result<(), Error> {
        models.get::<StateManager>().draw_world();
        Ok(())
    }

    fn key_press(
        &mut self,
        models: &mut Models,
        key: i32,
        _scan: i32,
        _repeat: bool,
        _mods: KeyMods,
    ) -> Result<bool, Error> {
        models.with::<StateManager, _>(|states, models| states.key_press(models, key))
    }

    fn mouse_move(
        &mut self,
        models: &mut Models,
        x: i32,
        y: i32,
        _dx: i32,
        _dy: i32,
        button: i32,
    ) -> Result<bool, Error> {
        models.with::<StateManager, _>(|states, models| states.mouse_move(models, x, y, button))
    }

    fn mouse_press(
        &mut self,
        models: &mut Models,
        x: i32,
        y: i32,
        button: i32,
    ) -> Result<bool, Error> {
        models.with::<StateManager, _>(|states, models| states.mouse_press(models, x, y, button))
    }

    fn mouse_release(
        &mut self,
        models: &mut Models,
        x: i32,
        y: i32,
        button: i32,
    ) -> Result<(), Error> {
        models.with::<StateManager, _>(|states, models| states.mouse_release(models, x, y, button))
    }

    fn mouse_wheel(&mut self, models: &mut Models, up: bool, value: f32) -> Result<bool, Error> {
        models.with::<StateManager, _>(|states, models| states.mouse_wheel(models, up, value))
    }

    fn drain_commands(&mut self, models: &mut Models) -> Vec<Box<dyn Command>> {
        models.get::<StateManager>().drain_commands()
    }

    fn flush_commands_after(&self, event: Event) -> bool {
        matches!(
            event,
            Event::KeyPress | Event::MouseMove | Event::MousePress | Event::MouseRelease
        )
    }
}
