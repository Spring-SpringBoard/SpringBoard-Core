//! Engine input ownership and field-edit key handling.

use spring_native::prelude::Error;

use super::PanelManager;
use crate::sbc::keys::KeyMods;
use crate::sbc::panels::field_target::ActiveFieldEditor;
use crate::sbc::states::trace::rml_y_from_callback;

impl PanelManager {
    pub fn key_press(
        &mut self,
        key: i32,
        _scan: i32,
        _repeat: bool,
        mods: KeyMods,
    ) -> Result<bool, Error> {
        if !self.enabled {
            return Ok(false);
        }
        const RETURN: i32 = 13;
        const ESCAPE: i32 = 27;
        let Some(name) = self.session.editing().map(str::to_string) else {
            if key == ESCAPE && self.close_top_modal()? {
                return Ok(true);
            }
            return Ok(self.hotkeys.match_hotkey(&self.interface, key, mods));
        };
        if key == RETURN {
            let mut target = ActiveFieldEditor::new(&mut self.modals, &mut self.slot);
            let commands =
                self.session
                    .commit_field(&name, false, target.get_mut(), &self.interface);
            self.pending_commands.extend(commands);
            return Ok(true);
        }
        if key == ESCAPE {
            let mut target = ActiveFieldEditor::new(&mut self.modals, &mut self.slot);
            self.session
                .revert_field(&name, target.get_mut(), &self.interface);
            return Ok(true);
        }
        if mods.ctrl && crate::sbc::keys::is_key(&self.interface, key, "a") {
            let mut target = ActiveFieldEditor::new(&mut self.modals, &mut self.slot);
            if let Some(ed) = target.get_mut() {
                ed.select_edit_field(&name, &self.interface);
            }
        }
        Ok(true)
    }

    pub fn key_release(&mut self, _key: i32, _scan: i32) -> Result<bool, Error> {
        Ok(self.enabled && self.session.editing().is_some())
    }

    pub fn text_input(&mut self, _utf8: &str) -> Result<bool, Error> {
        Ok(self.enabled && self.session.editing().is_some())
    }

    pub fn mouse_move(
        &mut self,
        x: i32,
        y: i32,
        _dx: i32,
        _dy: i32,
        _button: i32,
    ) -> Result<bool, Error> {
        if !self.enabled {
            return Ok(false);
        }
        let y = rml_y_from_callback(&self.interface, y);
        self.input.mouse_move(&self.interface, &self.view, x, y)
    }

    pub fn mouse_press(&mut self, x: i32, y: i32, button: i32) -> Result<bool, Error> {
        if !self.enabled {
            return Ok(false);
        }
        let y = rml_y_from_callback(&self.interface, y);
        // This must happen before the hit test below. A right-click on the map
        // is outside the panel, but it still interrupts an active numeric drag
        // owned by the panel.
        if let Some(action) = self.input.interrupt_drag(&self.interface) {
            self.process_interaction(action)?;
        }
        let modal_open =
            self.modals.any_open() || self.slot.editor().is_some_and(|ed| ed.has_open_modal());
        let inside = self.view.contains(&self.interface, x, y);
        if !inside && !modal_open {
            return Ok(false);
        }
        self.input
            .mouse_press(&self.interface, &self.view, x, y, button)
    }

    pub fn mouse_release(&mut self, x: i32, y: i32, button: i32) -> Result<(), Error> {
        if !self.enabled {
            return Ok(());
        }
        let y = rml_y_from_callback(&self.interface, y);
        self.input
            .mouse_release(&self.interface, &self.view, x, y, button)
    }

    pub fn mouse_wheel(&mut self, up: bool, value: f32) -> Result<bool, Error> {
        if !self.enabled {
            return Ok(false);
        }
        self.input
            .mouse_wheel(&self.interface, &self.view, up, value)
    }
}
