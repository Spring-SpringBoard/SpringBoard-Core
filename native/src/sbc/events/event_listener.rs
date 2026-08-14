use spring_native::prelude::{Error, NativeInterfaceRef};

use crate::sbc::command_system::command::{Command, CommandId};
use crate::sbc::command_system::model::Models;
use crate::sbc::keys::KeyMods;

use super::order::ListenerId;

#[allow(clippy::too_many_arguments)]
pub(crate) trait EventListener {
    fn id(&self) -> ListenerId;
    fn handles(&self, event: super::Event) -> bool;

    fn add_console_line(
        &mut self,
        models: &mut Models,
        message: &str,
        section: &str,
        level: i32,
    ) -> Result<bool, Error> {
        let _ = (models, message, section, level);
        Ok(false)
    }
    fn command_applied(&mut self, models: &mut Models) {
        let _ = models;
    }
    fn command_history_changed(
        &mut self,
        models: &mut Models,
        undo_ids: &[CommandId],
        redo_ids: &[CommandId],
    ) {
        let _ = (models, undo_ids, redo_ids);
    }
    fn command_recorded(&mut self, models: &mut Models, id: CommandId, name: &str) {
        let _ = (models, id, name);
    }
    fn drain_commands(&mut self, models: &mut Models) -> Vec<Box<dyn Command>> {
        let _ = models;
        Vec::new()
    }
    fn draw_screen(
        &mut self,
        models: &mut Models,
        view_size_x: i32,
        view_size_y: i32,
    ) -> Result<(), Error> {
        let _ = (models, view_size_x, view_size_y);
        Ok(())
    }
    fn draw_screen_post(
        &mut self,
        models: &mut Models,
        view_size_x: i32,
        view_size_y: i32,
    ) -> Result<(), Error> {
        let _ = (models, view_size_x, view_size_y);
        Ok(())
    }
    fn draw_world(&mut self, models: &mut Models) -> Result<(), Error> {
        let _ = models;
        Ok(())
    }
    fn draw_world_pre_unit(&mut self, models: &mut Models) -> Result<(), Error> {
        let _ = models;
        Ok(())
    }
    fn key_press(
        &mut self,
        models: &mut Models,
        key_code: i32,
        scan_code: i32,
        is_repeat: bool,
        label: &str,
        utf32_char: i32,
        mods: KeyMods,
    ) -> Result<bool, Error> {
        let _ = (
            models, key_code, scan_code, is_repeat, label, utf32_char, mods,
        );
        Ok(false)
    }
    fn key_release(
        &mut self,
        models: &mut Models,
        key_code: i32,
        scan_code: i32,
        label: &str,
        utf32_char: i32,
        mods: KeyMods,
    ) -> Result<bool, Error> {
        let _ = (models, key_code, scan_code, label, utf32_char, mods);
        Ok(false)
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
        let _ = (models, x, y, dx, dy, button);
        Ok(false)
    }
    fn mouse_press(
        &mut self,
        models: &mut Models,
        x: i32,
        y: i32,
        button: i32,
    ) -> Result<bool, Error> {
        let _ = (models, x, y, button);
        Ok(false)
    }
    fn mouse_release(
        &mut self,
        models: &mut Models,
        x: i32,
        y: i32,
        button: i32,
    ) -> Result<(), Error> {
        let _ = (models, x, y, button);
        Ok(())
    }
    fn mouse_wheel(&mut self, models: &mut Models, up: bool, value: f32) -> Result<bool, Error> {
        let _ = (models, up, value);
        Ok(false)
    }
    fn text_input(&mut self, models: &mut Models, utf8: &str) -> Result<bool, Error> {
        let _ = (models, utf8);
        Ok(false)
    }
    fn update(&mut self, models: &mut Models) -> Result<(), Error> {
        let _ = models;
        Ok(())
    }
}

pub(crate) struct EventListenerFactory {
    pub make: fn(NativeInterfaceRef) -> Box<dyn EventListener>,
}
inventory::collect!(EventListenerFactory);
