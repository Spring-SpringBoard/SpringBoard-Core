use spring_native::prelude::{Error, NativeInterfaceRef};

use super::events::{ChonsoleEvents, KeyOutcome};
use super::view::ChonsoleView;
use crate::sbc::chonsole::commands::ChonsoleCore;
use crate::sbc::chonsole::framework::ChonsoleResponse;

#[derive(Default)]
pub struct ChonsoleController {
    view: ChonsoleView,
    events: ChonsoleEvents,
}

pub enum UiKeyOutcome {
    Unhandled,
    Handled,
    Execute(String),
}

impl ChonsoleController {
    pub fn dispose(&mut self, interface: &NativeInterfaceRef) {
        self.view.dispose(interface);
    }
    pub fn visible(&self) -> bool {
        self.view.visible()
    }
    pub fn apply_response(&mut self, response: &ChonsoleResponse, core: &ChonsoleCore) {
        self.view.apply_response(response, core);
        self.events.reset_history_cursor();
    }
    pub fn clear(&mut self) {
        self.view.clear();
        self.events.reset_history_cursor();
    }
    pub fn update(
        &mut self,
        interface: &NativeInterfaceRef,
        core: &ChonsoleCore,
    ) -> Result<(), Error> {
        self.view.ensure(interface, core)?;
        if self.view.process_suggestion_clicks(core) {
            self.view.refresh(interface, core)?;
        }
        self.view.process_suggestion_hovers()?;
        self.view.update(interface)
    }
    pub fn draw_screen(&mut self, interface: &NativeInterfaceRef) -> Result<(), Error> {
        self.view.draw_screen(interface)
    }
    pub fn key_press(
        &mut self,
        interface: &NativeInterfaceRef,
        core: &ChonsoleCore,
        key_code: i32,
        scan_code: i32,
        is_repeat: bool,
    ) -> Result<UiKeyOutcome, Error> {
        Ok(
            match self.events.key_press(
                interface,
                core,
                &mut self.view,
                key_code,
                scan_code,
                is_repeat,
            )? {
                KeyOutcome::Unhandled => UiKeyOutcome::Unhandled,
                KeyOutcome::Handled => UiKeyOutcome::Handled,
                KeyOutcome::Execute(input) => UiKeyOutcome::Execute(input),
            },
        )
    }
    pub fn text_key(
        &mut self,
        interface: &NativeInterfaceRef,
        core: &ChonsoleCore,
        key_code: i32,
    ) -> Result<bool, Error> {
        self.events
            .text_key(interface, core, &mut self.view, key_code)
    }
    pub fn hide(&mut self, interface: &NativeInterfaceRef) -> Result<(), Error> {
        self.view.set_visible(interface, false)
    }
    pub fn key_release(
        &mut self,
        interface: &NativeInterfaceRef,
        key_code: i32,
        scan_code: i32,
    ) -> Result<bool, Error> {
        self.events
            .key_release(interface, &mut self.view, key_code, scan_code)
    }
    pub fn text_input(
        &mut self,
        interface: &NativeInterfaceRef,
        core: &ChonsoleCore,
        utf8: &str,
    ) -> Result<bool, Error> {
        self.events
            .text_input(interface, core, &mut self.view, utf8)
    }
    pub fn mouse_move(
        &mut self,
        interface: &NativeInterfaceRef,
        x: i32,
        y: i32,
    ) -> Result<bool, Error> {
        self.view.mouse_move(interface, x, y)
    }
    pub fn mouse_press(
        &mut self,
        interface: &NativeInterfaceRef,
        x: i32,
        y: i32,
        button: i32,
    ) -> Result<bool, Error> {
        self.view.mouse_press(interface, x, y, button)
    }
    pub fn mouse_release(
        &mut self,
        interface: &NativeInterfaceRef,
        x: i32,
        y: i32,
        button: i32,
    ) -> Result<(), Error> {
        self.view.mouse_release(interface, x, y, button)
    }
    pub fn mouse_wheel(
        &mut self,
        interface: &NativeInterfaceRef,
        up: bool,
        value: f32,
    ) -> Result<bool, Error> {
        self.view.mouse_wheel(interface, up, value)
    }
}
