use super::super::registry::CommandRegistration;
use super::super::ChonsoleAction;

inventory::submit! { CommandRegistration {
    name: "clear",
    description: "Clear native chonsole history.",
    requires_cheat: false,
    execute: |_| ChonsoleAction::Clear,
} }
