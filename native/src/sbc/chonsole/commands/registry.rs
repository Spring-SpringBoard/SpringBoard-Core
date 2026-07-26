//! Discovery and dispatch for Chonsole command registrations.

use super::{ChatTarget, ChonsoleAction, ChonsoleCore, ConsoleCommand};

/// One self-contained Chonsole command.
///
/// Feature modules submit these rather than modifying command dispatch.
/// Inventory order is intentionally unspecified, so the registry sorts command
/// metadata before exposing it to completion and `/help`.
pub(super) struct CommandRegistration {
    pub name: &'static str,
    pub description: &'static str,
    pub requires_cheat: bool,
    pub execute: fn(&str) -> ChonsoleAction,
}

inventory::collect!(CommandRegistration);

pub struct CommandRegistry {
    registrations: Vec<&'static CommandRegistration>,
}

impl Default for CommandRegistry {
    fn default() -> Self {
        let mut registrations: Vec<_> =
            inventory::iter::<CommandRegistration>.into_iter().collect();
        registrations.sort_by_key(|registration| registration.name);
        for pair in registrations.windows(2) {
            assert_ne!(
                pair[0].name, pair[1].name,
                "duplicate Chonsole command registration: {}",
                pair[0].name
            );
        }
        Self { registrations }
    }
}

impl CommandRegistry {
    pub fn install(&self, core: &mut ChonsoleCore) {
        core.set_local_commands(
            self.registrations
                .iter()
                .map(|registration| ConsoleCommand {
                    name: registration.name.into(),
                    description: registration.description.into(),
                    requires_cheat: registration.requires_cheat,
                })
                .collect(),
        );
    }

    pub fn resolve(&self, input: &str) -> ChonsoleAction {
        let input = input.trim();
        if input.is_empty() {
            return ChonsoleAction::Empty;
        }
        if !input.starts_with('/') {
            return ChonsoleAction::Chat(ChatTarget::Default, input.to_string());
        }

        let stripped = input.trim_start_matches('/').trim();
        let (name, args) = stripped
            .split_once(char::is_whitespace)
            .map(|(name, args)| (name, args.trim()))
            .unwrap_or((stripped, ""));
        if let Some(registration) = self
            .registrations
            .iter()
            .find(|registration| registration.name.eq_ignore_ascii_case(name))
        {
            return (registration.execute)(args);
        }

        let command = name.to_ascii_lowercase();
        ChonsoleAction::EngineCommand {
            force_cheat: command == "luarules" && args.split_whitespace().next() == Some("reload"),
            command,
            args: args.to_string(),
            display: stripped.to_string(),
        }
    }
}
