//! Hotkey matching for toolbar actions. Matches are queued and run next tick,
//! where the models are borrowable.

use spring_native::prelude::NativeInterfaceRef;

use crate::sbc::actions::Action;

#[derive(Default)]
pub(crate) struct ActionDispatcher {
    pending: Vec<Action>,
}

impl ActionDispatcher {
    /// Match a key + current modifiers against the action hotkeys, queueing the
    /// match. Returns whether a hotkey was claimed.
    pub(crate) fn match_hotkey(&mut self, interface: &NativeInterfaceRef, key: i32) -> bool {
        const SHIFT: u32 = 1 << 0;
        const CTRL: u32 = 1 << 1;
        let mods = interface.input().get_mod_key_state().unwrap_or(0);
        let (ctrl, shift) = (mods & CTRL != 0, mods & SHIFT != 0);

        for action in Action::ALL {
            let Some(hk) = action.hotkey() else { continue };
            if hk.ctrl == ctrl
                && hk.shift == shift
                && crate::sbc::keys::is_key(interface, key, hk.key)
            {
                self.pending.push(action);
                return true;
            }
        }
        false
    }

    pub(crate) fn take(&mut self) -> Vec<Action> {
        std::mem::take(&mut self.pending)
    }

    pub(crate) fn clear(&mut self) {
        self.pending.clear();
    }
}
