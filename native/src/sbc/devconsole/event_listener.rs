//! Developer-console registrations at the native-module boundary.

use spring_native::prelude::Error;

use super::manager::DevConsoleManager;
use crate::sbc::command_system::command::{Command, CommandId};
use crate::sbc::command_system::model::Models;
use crate::sbc::events::{Event, EventListener, EventListenerFactory, ListenerId};

inventory::submit! { EventListenerFactory { make: |_| Box::new(DevConsoleTextEvents) } }
inventory::submit! { EventListenerFactory { make: |_| Box::new(DevConsoleEvents) } }

struct DevConsoleTextEvents;

impl EventListener for DevConsoleTextEvents {
    fn id(&self) -> ListenerId {
        ListenerId::DevConsoleText
    }

    fn handles(&self, event: Event) -> bool {
        matches!(event, Event::KeyPress)
    }

    fn key_press(
        &mut self,
        models: &mut Models,
        key: i32,
        _scan: i32,
        _repeat: bool,
    ) -> Result<bool, Error> {
        models.get::<DevConsoleManager>().text_key(key)
    }
}

struct DevConsoleEvents;

impl EventListener for DevConsoleEvents {
    fn id(&self) -> ListenerId {
        ListenerId::DevConsole
    }

    fn handles(&self, event: Event) -> bool {
        matches!(
            event,
            Event::KeyPress
                | Event::ConsoleLine
                | Event::CommandRecorded
                | Event::CommandHistoryChanged
        )
    }

    fn update(&mut self, models: &mut Models) -> Result<(), Error> {
        models.with::<DevConsoleManager, _>(|console, models| console.update(models))
    }

    fn key_press(
        &mut self,
        models: &mut Models,
        key: i32,
        _scan: i32,
        _repeat: bool,
    ) -> Result<bool, Error> {
        models.get::<DevConsoleManager>().key_press(key)
    }

    fn console_line(
        &mut self,
        models: &mut Models,
        message: &str,
        level: i32,
    ) -> Result<bool, Error> {
        models
            .get::<DevConsoleManager>()
            .add_console_line(message, level);
        Ok(false)
    }

    fn drain_commands(&mut self, models: &mut Models) -> Vec<Box<dyn Command>> {
        models.get::<DevConsoleManager>().drain_commands()
    }

    fn command_recorded(&mut self, models: &mut Models, id: CommandId, name: &str) {
        models
            .get::<DevConsoleManager>()
            .record_command(id, name.to_string());
    }

    fn command_history_changed(
        &mut self,
        models: &mut Models,
        undo: &[CommandId],
        redo: &[CommandId],
    ) {
        models
            .get::<DevConsoleManager>()
            .sync_command_history(undo, redo);
    }
}
