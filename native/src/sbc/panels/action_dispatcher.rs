//! Hotkey matching for toolbar actions. Matches are queued and run next tick,
//! where the models are borrowable.

use spring_native::prelude::NativeInterfaceRef;

use crate::sbc::actions::Action;
use crate::sbc::keys::KeyMods;

#[derive(Default)]
pub(crate) struct ActionDispatcher {
    pending: Vec<Action>,
}

impl ActionDispatcher {
    /// Match a key + current modifiers against the action hotkeys, queueing the
    /// match. Returns whether a hotkey was claimed.
    pub(crate) fn match_hotkey(
        &mut self,
        interface: &NativeInterfaceRef,
        key: i32,
        mods: KeyMods,
    ) -> bool {
        for action in Action::ALL {
            let Some(hk) = action.hotkey() else { continue };
            if hk.ctrl == mods.ctrl
                && hk.shift == mods.shift
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
