//! Toolbar actions. Each is a button in the dev console's toolbar.

use spring_native::prelude::NativeInterfaceRef;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub(crate) enum Action {
    Clear,
    FilterProblems,
    Restart,
    ReloadLuaUi,
    ReloadLuaRules,
    ToggleCheating,
    ToggleGlobalLos,
    ToggleGodMode,
    TogglePopupOnError,
    ToggleVisibility,
}

impl Action {
    /// Toolbar order, mirroring `dbg_dev_console.html`. `Debug Mode` and
    /// `Toggle profiling` are omitted: they drive Lua-side state that the
    /// native UI does not own.
    pub(crate) const ALL: [Action; 10] = [
        Action::Clear,
        Action::FilterProblems,
        Action::Restart,
        Action::ReloadLuaUi,
        Action::ReloadLuaRules,
        Action::ToggleCheating,
        Action::ToggleGlobalLos,
        Action::ToggleGodMode,
        Action::TogglePopupOnError,
        Action::ToggleVisibility,
    ];

    pub(crate) fn id(self) -> &'static str {
        match self {
            Action::Clear => "btn-clear",
            Action::FilterProblems => "btn-filter-problems",
            Action::Restart => "btn-restart",
            Action::ReloadLuaUi => "btn-reload-luaui",
            Action::ReloadLuaRules => "btn-reload-luarules",
            Action::ToggleCheating => "btn-cheating",
            Action::ToggleGlobalLos => "btn-globallos",
            Action::ToggleGodMode => "btn-godmode",
            Action::TogglePopupOnError => "btn-popup",
            Action::ToggleVisibility => "btn-visibility",
        }
    }

    /// Toggles render pressed when their state is on.
    pub(crate) fn is_toggle(self) -> bool {
        !matches!(
            self,
            Action::Clear | Action::Restart | Action::ReloadLuaUi | Action::ReloadLuaRules
        )
    }
}

/// `globallos`, `godmode` and `luarules reload` are cheat-gated, exactly as in
/// the Lua console.
pub(crate) fn cheat_if_needed(interface: &NativeInterfaceRef) {
    if !interface.game().is_cheating_enabled().unwrap_or(false) {
        let _ = interface.messages().send_commands("cheat", "");
    }
}

pub(crate) fn is_cheating(interface: &NativeInterfaceRef) -> bool {
    interface.game().is_cheating_enabled().unwrap_or(false)
}

pub(crate) fn is_god_mode(interface: &NativeInterfaceRef) -> bool {
    interface.game().is_god_mode_enabled().unwrap_or(false)
}

pub(crate) fn is_global_los(interface: &NativeInterfaceRef) -> bool {
    let Ok(ally_team) = interface.player().get_local_ally_team_id() else {
        return false;
    };
    interface
        .game()
        .get_global_los(ally_team)
        .is_ok_and(|los| los != 0)
}
