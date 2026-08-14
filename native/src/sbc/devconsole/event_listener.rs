use spring_native::prelude::Error;

use super::console_controller::ConsoleController;
use crate::sbc::command_system::command::{Command, CommandId};
use crate::sbc::command_system::model::Models;
use crate::sbc::events::{Event, EventListener, EventListenerFactory, ListenerId};
use crate::sbc::keys::KeyMods;

inventory::submit! { EventListenerFactory { make: |_| Box::new(DevConsoleEvents) } }

struct DevConsoleEvents;

impl EventListener for DevConsoleEvents {
    fn id(&self) -> ListenerId {
        ListenerId::DevConsole
    }

    fn handles(&self, event: Event) -> bool {
        matches!(
            event,
            Event::KeyPress
                | Event::KeyRelease
                | Event::AddConsoleLine
                | Event::CommandRecorded
                | Event::CommandHistoryChanged
        )
    }

    fn update(&mut self, models: &mut Models) -> Result<(), Error> {
        models.with::<ConsoleController, _>(|console, models| console.update(models))
    }

    fn key_press(
        &mut self,
        models: &mut Models,
        key: i32,
        _scan: i32,
        _repeat: bool,
        _label: &str,
        _utf32_char: i32,
        mods: KeyMods,
    ) -> Result<bool, Error> {
        models.get::<ConsoleController>().key_press(key, mods)
    }

    fn key_release(
        &mut self,
        models: &mut Models,
        key: i32,
        _scan: i32,
        _label: &str,
        _utf32_char: i32,
        _mods: KeyMods,
    ) -> Result<bool, Error> {
        models.get::<ConsoleController>().key_release(key)
    }

    fn add_console_line(
        &mut self,
        models: &mut Models,
        message: &str,
        _section: &str,
        level: i32,
    ) -> Result<bool, Error> {
        models
            .get::<ConsoleController>()
            .add_console_line(message, level);
        Ok(false)
    }

    fn drain_commands(&mut self, models: &mut Models) -> Vec<Box<dyn Command>> {
        models.get::<ConsoleController>().drain_commands()
    }

    fn command_recorded(&mut self, models: &mut Models, id: CommandId, name: &str) {
        models.get::<ConsoleController>().record_command(id, name);
    }

    fn command_history_changed(
        &mut self,
        models: &mut Models,
        undo: &[CommandId],
        redo: &[CommandId],
    ) {
        models
            .get::<ConsoleController>()
            .sync_command_history(undo, redo);
    }
}
