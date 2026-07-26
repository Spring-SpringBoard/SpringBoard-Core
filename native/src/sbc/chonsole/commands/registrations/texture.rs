use super::super::registry::CommandRegistration;
use super::super::ChonsoleAction;

inventory::submit! { CommandRegistration {
    name: "texture",
    description: "Preview or export an engine texture.",
    requires_cheat: false,
    execute: |args| ChonsoleAction::TextureExport(args.to_string()),
} }
