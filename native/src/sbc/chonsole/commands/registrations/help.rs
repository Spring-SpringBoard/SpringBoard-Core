use super::super::registry::CommandRegistration;
use super::super::ChonsoleAction;

inventory::submit! { CommandRegistration {
    name: "help",
    description: "List chonsole commands.",
    requires_cheat: false,
    execute: |_| ChonsoleAction::Help,
} }
