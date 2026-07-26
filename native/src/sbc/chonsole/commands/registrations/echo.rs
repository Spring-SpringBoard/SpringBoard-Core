use super::super::registry::CommandRegistration;
use super::super::ChonsoleAction;

inventory::submit! { CommandRegistration {
    name: "echo",
    description: "Echo text through the native console.",
    requires_cheat: false,
    execute: |args| ChonsoleAction::Echo(args.to_string()),
} }
