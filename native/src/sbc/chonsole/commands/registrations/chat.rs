//! Chonsole's chat-route aliases.

use super::super::registry::CommandRegistration;
use super::super::{ChatTarget, ChonsoleAction};

inventory::submit! { CommandRegistration {
    name: "a",
    description: "Send public chat.",
    requires_cheat: false,
    execute: |args| ChonsoleAction::Chat(ChatTarget::Public, args.to_string()),
} }

inventory::submit! { CommandRegistration {
    name: "s",
    description: "Send spectator chat.",
    requires_cheat: false,
    execute: |args| ChonsoleAction::Chat(ChatTarget::Spectator, args.to_string()),
} }

inventory::submit! { CommandRegistration {
    name: "t",
    description: "Send ally chat.",
    requires_cheat: false,
    execute: |args| ChonsoleAction::Chat(ChatTarget::Ally, args.to_string()),
} }
