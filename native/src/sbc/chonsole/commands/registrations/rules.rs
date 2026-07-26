//! Lua-compatible game, team, and selected-unit rule commands.

use super::super::registry::CommandRegistration;
use super::super::{ChonsoleAction, RuleScope};

inventory::submit! { CommandRegistration {
    name: "gamerules",
    description: "Set a game rules parameter.",
    requires_cheat: true,
    execute: |args| ChonsoleAction::RuleCommand {
        scope: RuleScope::Game,
        args: args.to_string(),
    },
} }

inventory::submit! { CommandRegistration {
    name: "teamrules",
    description: "Set a team rules parameter.",
    requires_cheat: true,
    execute: |args| ChonsoleAction::RuleCommand {
        scope: RuleScope::Team,
        args: args.to_string(),
    },
} }

inventory::submit! { CommandRegistration {
    name: "unitrules",
    description: "Set a rules parameter on selected units.",
    requires_cheat: true,
    execute: |args| ChonsoleAction::RuleCommand {
        scope: RuleScope::Unit,
        args: args.to_string(),
    },
} }
