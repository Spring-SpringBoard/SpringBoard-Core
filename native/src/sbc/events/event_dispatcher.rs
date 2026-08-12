use spring_native::prelude::{Error, NativeInterfaceRef};

use crate::sbc::command_system::command::{Command, CommandId};
use crate::sbc::command_system::model::Models;
use crate::sbc::keys::KeyMods;

use super::event_listener::{EventListener, EventListenerFactory};
use super::order::Event;

pub(crate) struct EventDispatcher {
    listeners: Vec<Box<dyn EventListener>>,
    pending_commands: Vec<Box<dyn Command>>,
}

#[allow(clippy::too_many_arguments)]
impl EventDispatcher {
    pub(crate) fn new(interface: NativeInterfaceRef) -> Self {
        EventDispatcher {
            listeners: inventory::iter::<EventListenerFactory>
                .into_iter()
                .map(|factory| (factory.make)(interface))
                .collect(),
            pending_commands: Vec::new(),
        }
    }

    pub(crate) fn add_console_line(
        &mut self,
        models: &mut Models,
        message: &str,
        section: &str,
        level: i32,
    ) -> Result<bool, Error> {
        for index in self.indices(Event::AddConsoleLine) {
            let handled = self.listeners[index].add_console_line(models, message, section, level)?;
            if handled {
                return Ok(true);
            }
        }
        Ok(false)
    }

    pub(crate) fn command_applied(&mut self, models: &mut Models) {
        for index in self.indices(Event::CommandApplied) {
            self.listeners[index].command_applied(models);
        }
    }

    pub(crate) fn command_history_changed(
        &mut self,
        models: &mut Models,
        undo_ids: &[CommandId],
        redo_ids: &[CommandId],
    ) {
        for index in self.indices(Event::CommandHistoryChanged) {
            self.listeners[index].command_history_changed(models, undo_ids, redo_ids);
        }
    }

    pub(crate) fn command_recorded(&mut self, models: &mut Models, id: CommandId, name: &str) {
        for index in self.indices(Event::CommandRecorded) {
            self.listeners[index].command_recorded(models, id, name);
        }
    }

    pub(crate) fn draw_screen(&mut self, models: &mut Models, view_size_x: i32, view_size_y: i32) -> Result<(), Error> {
        for index in self.indices(Event::DrawScreen) {
            self.listeners[index].draw_screen(models, view_size_x, view_size_y)?;
        }
        Ok(())
    }

    pub(crate) fn draw_screen_post(&mut self, models: &mut Models, view_size_x: i32, view_size_y: i32) -> Result<(), Error> {
        for index in self.indices(Event::DrawScreenPost) {
            self.listeners[index].draw_screen_post(models, view_size_x, view_size_y)?;
        }
        Ok(())
    }

    pub(crate) fn draw_world(&mut self, models: &mut Models) -> Result<(), Error> {
        for index in self.indices(Event::DrawWorld) {
            self.listeners[index].draw_world(models)?;
        }
        Ok(())
    }

    pub(crate) fn draw_world_pre_unit(&mut self, models: &mut Models) -> Result<(), Error> {
        for index in self.indices(Event::DrawWorldPreUnit) {
            self.listeners[index].draw_world_pre_unit(models)?;
        }
        Ok(())
    }

    pub(crate) fn key_press(
        &mut self,
        models: &mut Models,
        key_code: i32,
        scan_code: i32,
        is_repeat: bool,
        label: &str,
        utf32_char: i32,
        mods: KeyMods,
    ) -> Result<bool, Error> {
        for index in self.indices(Event::KeyPress) {
            let handled =
                self.listeners[index].key_press(models, key_code, scan_code, is_repeat, label, utf32_char, mods)?;
            if handled {
                return Ok(true);
            }
        }
        Ok(false)
    }

    pub(crate) fn key_release(
        &mut self,
        models: &mut Models,
        key_code: i32,
        scan_code: i32,
        label: &str,
        utf32_char: i32,
        mods: KeyMods,
    ) -> Result<bool, Error> {
        for index in self.indices(Event::KeyRelease) {
            let handled = self.listeners[index].key_release(models, key_code, scan_code, label, utf32_char, mods)?;
            if handled {
                return Ok(true);
            }
        }
        Ok(false)
    }

    pub(crate) fn mouse_move(
        &mut self,
        models: &mut Models,
        x: i32,
        y: i32,
        dx: i32,
        dy: i32,
        button: i32,
    ) -> Result<bool, Error> {
        for index in self.indices(Event::MouseMove) {
            let handled = self.listeners[index].mouse_move(models, x, y, dx, dy, button)?;
            if handled {
                return Ok(true);
            }
        }
        Ok(false)
    }

    pub(crate) fn mouse_press(
        &mut self,
        models: &mut Models,
        x: i32,
        y: i32,
        button: i32,
    ) -> Result<bool, Error> {
        for index in self.indices(Event::MousePress) {
            let handled = self.listeners[index].mouse_press(models, x, y, button)?;
            if handled {
                return Ok(true);
            }
        }
        Ok(false)
    }

    pub(crate) fn mouse_release(
        &mut self,
        models: &mut Models,
        x: i32,
        y: i32,
        button: i32,
    ) -> Result<(), Error> {
        for index in self.indices(Event::MouseRelease) {
            self.listeners[index].mouse_release(models, x, y, button)?;
        }
        Ok(())
    }

    pub(crate) fn mouse_wheel(
        &mut self,
        models: &mut Models,
        up: bool,
        value: f32,
    ) -> Result<bool, Error> {
        for index in self.indices(Event::MouseWheel) {
            let handled = self.listeners[index].mouse_wheel(models, up, value)?;
            if handled {
                return Ok(true);
            }
        }
        Ok(false)
    }

    pub(crate) fn take_commands(&mut self, models: &mut Models) -> Vec<Box<dyn Command>> {
        for listener in &mut self.listeners {
            self.pending_commands.extend(listener.drain_commands(models));
        }
        std::mem::take(&mut self.pending_commands)
    }

    pub(crate) fn text_input(&mut self, models: &mut Models, utf8: &str) -> Result<bool, Error> {
        for index in self.indices(Event::TextInput) {
            let handled = self.listeners[index].text_input(models, utf8)?;
            if handled {
                return Ok(true);
            }
        }
        Ok(false)
    }

    pub(crate) fn update(&mut self, models: &mut Models) -> Result<(), Error> {
        for listener in &mut self.listeners {
            listener.update(models)?;
            let commands = listener.drain_commands(models);
            self.pending_commands.extend(commands);
        }
        Ok(())
    }

    fn indices(&self, event: Event) -> Vec<usize> {
        let mut indices = self
            .listeners
            .iter()
            .enumerate()
            .filter(|(_, listener)| listener.handles(event))
            .map(|(index, listener)| (listener.id().event_priority(event), index))
            .collect::<Vec<_>>();
        indices.sort_unstable();
        indices.into_iter().map(|(_, index)| index).collect()
    }
}
