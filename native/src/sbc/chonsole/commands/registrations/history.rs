use super::super::registry::CommandRegistration;
use super::super::ChonsoleAction;

inventory::submit! { CommandRegistration {
    name: "history",
    description: "Show native chonsole input history.",
    requires_cheat: false,
    execute: |_| ChonsoleAction::History,
} }
