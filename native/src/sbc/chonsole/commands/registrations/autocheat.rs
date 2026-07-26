use super::super::registry::CommandRegistration;
use super::super::ChonsoleAction;

inventory::submit! { CommandRegistration {
    name: "autocheat",
    description: "Toggle automatic /cheat wrapping for cheat-only commands.",
    requires_cheat: false,
    execute: |_| ChonsoleAction::ToggleAutoCheat,
} }
