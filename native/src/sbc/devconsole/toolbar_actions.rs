use spring_native::prelude::{Error, NativeInterfaceRef};

use crate::sbc::devconsole::log_model::LogModel;
use crate::sbc::devconsole::view::ConsoleView;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub(crate) enum ToolbarAction {
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

pub(crate) struct ToolbarActionContext<'a> {
    pub(crate) interface: &'a NativeInterfaceRef,
    pub(crate) log: &'a mut LogModel,
    pub(crate) view: &'a mut ConsoleView,
}

impl ToolbarAction {
    pub(crate) const ALL: [ToolbarAction; 10] = [
        ToolbarAction::Clear,
        ToolbarAction::FilterProblems,
        ToolbarAction::Restart,
        ToolbarAction::ReloadLuaUi,
        ToolbarAction::ReloadLuaRules,
        ToolbarAction::ToggleCheating,
        ToolbarAction::ToggleGlobalLos,
        ToolbarAction::ToggleGodMode,
        ToolbarAction::TogglePopupOnError,
        ToolbarAction::ToggleVisibility,
    ];

    pub(crate) fn id(self) -> &'static str {
        match self {
            ToolbarAction::Clear => "btn-clear",
            ToolbarAction::FilterProblems => "btn-filter-problems",
            ToolbarAction::Restart => "btn-restart",
            ToolbarAction::ReloadLuaUi => "btn-reload-luaui",
            ToolbarAction::ReloadLuaRules => "btn-reload-luarules",
            ToolbarAction::ToggleCheating => "btn-cheating",
            ToolbarAction::ToggleGlobalLos => "btn-globallos",
            ToolbarAction::ToggleGodMode => "btn-godmode",
            ToolbarAction::TogglePopupOnError => "btn-popup",
            ToolbarAction::ToggleVisibility => "btn-visibility",
        }
    }

    pub(crate) fn pressed_binding(self) -> Option<&'static str> {
        Some(match self {
            ToolbarAction::Clear
            | ToolbarAction::Restart
            | ToolbarAction::ReloadLuaUi
            | ToolbarAction::ReloadLuaRules => return None,
            ToolbarAction::FilterProblems => "toolbar_filter_problems_pressed",
            ToolbarAction::ToggleCheating => "toolbar_cheating_pressed",
            ToolbarAction::ToggleGlobalLos => "toolbar_global_los_pressed",
            ToolbarAction::ToggleGodMode => "toolbar_god_mode_pressed",
            ToolbarAction::TogglePopupOnError => "toolbar_popup_on_error_pressed",
            ToolbarAction::ToggleVisibility => "toolbar_visibility_pressed",
        })
    }

    pub(crate) fn execute(self, context: &mut ToolbarActionContext<'_>) -> Result<(), Error> {
        match self {
            ToolbarAction::Clear => context.log.clear(),
            ToolbarAction::FilterProblems => {
                context.log.toggle_problems(context.interface);
                context.view.request_toggle_refresh();
            }
            ToolbarAction::TogglePopupOnError => context.view.toggle_popup_on_error(),
            ToolbarAction::ToggleVisibility => {
                let visible = !context.view.visible();
                context.view.set_visible(context.interface, visible)?;
                context.view.request_toggle_refresh();
            }
            ToolbarAction::Restart => {
                let _ = context.interface.system_control().restart("", "");
            }
            ToolbarAction::ReloadLuaUi => {
                let _ = context
                    .interface
                    .messages()
                    .send_commands("luaui reload", "");
            }
            ToolbarAction::ReloadLuaRules => {
                cheat_if_needed(context.interface);
                let _ = context
                    .interface
                    .messages()
                    .send_commands("luarules reload", "");
            }
            ToolbarAction::ToggleCheating => {
                let _ = context.interface.messages().send_commands("cheat", "");
                context.view.request_toggle_refresh();
            }
            ToolbarAction::ToggleGlobalLos => {
                cheat_if_needed(context.interface);
                let _ = context.interface.messages().send_commands("globallos", "");
                context.view.request_toggle_refresh();
            }
            ToolbarAction::ToggleGodMode => {
                cheat_if_needed(context.interface);
                let _ = context.interface.messages().send_commands("godmode", "");
                context.view.request_toggle_refresh();
            }
        }
        Ok(())
    }
}

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
