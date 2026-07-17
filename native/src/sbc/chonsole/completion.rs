//! Runtime command/value completion independent of input and rendering.

use std::collections::BTreeMap;

use super::types::ChonsoleSuggestion;

#[derive(Debug, Clone)]
pub(super) struct ConsoleCommand {
    pub(super) name: String,
    pub(super) description: String,
    pub(super) requires_cheat: bool,
}

pub(super) struct CompletionCatalog {
    commands: Vec<ConsoleCommand>,
    textures: Vec<String>,
    game_rules: Vec<(String, String)>,
    team_rules: BTreeMap<i32, Vec<(String, String)>>,
    unit_rules: Vec<(String, String)>,
    teams: Vec<i32>,
    unit_defs: Vec<(String, String)>,
    config_params: Vec<(String, String)>,
    players: Vec<String>,
}

impl Default for CompletionCatalog {
    fn default() -> Self {
        Self {
            commands: builtins(),
            textures: Vec::new(),
            game_rules: Vec::new(),
            team_rules: BTreeMap::new(),
            unit_rules: Vec::new(),
            teams: Vec::new(),
            unit_defs: Vec::new(),
            config_params: Vec::new(),
            players: Vec::new(),
        }
    }
}

impl CompletionCatalog {
    pub(super) fn commands(&self) -> &[ConsoleCommand] {
        &self.commands
    }

    pub(super) fn command_requires_cheat(&self, command: &str) -> bool {
        self.commands
            .iter()
            .find(|entry| entry.name == command)
            .is_some_and(|entry| entry.requires_cheat)
    }

    pub(super) fn suggestions(&self, input: &str) -> Vec<ChonsoleSuggestion> {
        let trimmed = input.trim_start();
        if let Some(argument) = trimmed.strip_prefix("/texture ") {
            if argument.split_whitespace().count() <= 1 {
                return self.textures(argument, "/texture", "Engine texture");
            }
        }
        if let Some(argument) = trimmed.strip_prefix("/gamerules ") {
            if argument.split_whitespace().count() <= 1 {
                return named_values(argument, "/gamerules", &self.game_rules);
            }
        }
        if let Some(argument) = trimmed.strip_prefix("/teamrules ") {
            let parts = argument.split_whitespace().collect::<Vec<_>>();
            if parts.is_empty()
                || (parts.len() == 1
                    && !argument.ends_with(char::is_whitespace)
                    && !self.teams.iter().any(|team| team.to_string() == parts[0]))
            {
                let prefix = parts.first().copied().unwrap_or("");
                return self
                    .teams
                    .iter()
                    .map(ToString::to_string)
                    .filter(|team| team.starts_with(prefix))
                    .map(|team| ChonsoleSuggestion {
                        command: format!("/teamrules {team}"),
                        text: team,
                        description: "Team rules".into(),
                    })
                    .collect();
            }
            let Some(team) = parts.first().and_then(|team| team.parse::<i32>().ok()) else {
                return Vec::new();
            };
            let rules = self
                .team_rules
                .get(&team)
                .map(Vec::as_slice)
                .unwrap_or_default();
            if parts.len() <= 2 {
                return rule_values(
                    "/teamrules",
                    &parts[..1],
                    parts.get(1).copied().unwrap_or(""),
                    rules,
                );
            }
        }
        if let Some(argument) = trimmed.strip_prefix("/unitrules ") {
            if argument.split_whitespace().count() <= 1 {
                return named_values(argument, "/unitrules", &self.unit_rules);
            }
        }
        if let Some(argument) = trimmed.strip_prefix("/set ") {
            return named_values(argument, "/set", &self.config_params);
        }
        if let Some(argument) = trimmed.strip_prefix("/w ") {
            let prefix = argument.split_whitespace().next().unwrap_or("");
            return self
                .players
                .iter()
                .filter(|name| name.starts_with(prefix))
                .map(|name| ChonsoleSuggestion {
                    command: format!("/w {name}"),
                    text: name.clone(),
                    description: String::new(),
                })
                .collect();
        }
        if let Some(argument) = trimmed.strip_prefix("/give ") {
            return self.give_values(argument);
        }
        let prefix = trimmed
            .strip_prefix('/')
            .unwrap_or(trimmed)
            .split_whitespace()
            .next()
            .unwrap_or("")
            .to_ascii_lowercase();
        let mut scored = self
            .commands
            .iter()
            .filter_map(|command| score(&command.name, &prefix).map(|score| (score, command)))
            .collect::<Vec<_>>();
        // Once a command matches, present the command catalogue in a stable
        // alphabetical order. Ranking fuzzy matches ahead of one another made
        // the list jump around and obscured where a command lives.
        scored.sort_by(|(_, left), (_, right)| left.name.cmp(&right.name));
        scored
            .into_iter()
            .map(|(_, command)| ChonsoleSuggestion {
                command: format!("/{}", command.name),
                text: command.name.clone(),
                description: command.description.clone(),
            })
            .collect()
    }

    pub(super) fn replace_commands(&mut self, mut commands: Vec<ConsoleCommand>) {
        commands.retain(|incoming| {
            !builtins()
                .iter()
                .any(|builtin| builtin.name == incoming.name)
        });
        let mut all = builtins();
        all.append(&mut commands);
        all.sort_by(|left, right| left.name.cmp(&right.name));
        self.commands = all;
    }

    pub(super) fn set_textures(&mut self, mut values: Vec<String>) {
        values.sort();
        values.dedup();
        self.textures = values;
    }

    pub(super) fn set_game_rules(&mut self, values: Vec<(String, String)>) {
        self.game_rules = values;
    }

    pub(super) fn set_team_rules(&mut self, mut values: BTreeMap<i32, Vec<(String, String)>>) {
        for rules in values.values_mut() {
            rules.sort_by(|left, right| left.0.cmp(&right.0));
            rules.dedup_by(|left, right| left.0 == right.0);
        }
        self.team_rules = values;
    }

    pub(super) fn set_unit_rules(&mut self, values: Vec<(String, String)>) {
        self.unit_rules = values;
    }

    pub(super) fn set_teams(&mut self, mut values: Vec<i32>) {
        values.sort();
        values.dedup();
        self.teams = values;
    }

    pub(super) fn set_unit_defs(&mut self, mut values: Vec<(String, String)>) {
        values.sort_by(|left, right| left.0.cmp(&right.0));
        self.unit_defs = values;
    }

    pub(super) fn set_config_params(&mut self, mut values: Vec<(String, String)>) {
        values.sort_by(|left, right| left.0.cmp(&right.0));
        self.config_params = values;
    }

    pub(super) fn set_players(&mut self, mut values: Vec<String>) {
        values.sort();
        values.dedup();
        self.players = values;
    }

    fn textures(
        &self,
        argument: &str,
        command: &str,
        description: &str,
    ) -> Vec<ChonsoleSuggestion> {
        let prefix = argument.split_whitespace().next().unwrap_or("");
        self.textures
            .iter()
            .filter(|name| name.starts_with(prefix))
            .map(|name| ChonsoleSuggestion {
                command: format!("{command} {name}"),
                text: name.clone(),
                description: description.into(),
            })
            .collect()
    }

    fn give_values(&self, argument: &str) -> Vec<ChonsoleSuggestion> {
        let parts = argument.split_whitespace().collect::<Vec<_>>();
        let (count, prefix): (Option<u32>, &str) = match parts.as_slice() {
            [] => (None, ""),
            [first] if first.parse::<u32>().is_ok() => (first.parse().ok(), ""),
            [first] => (None, *first),
            [count, name, ..] if count.parse::<u32>().is_ok() => (count.parse().ok(), *name),
            [name, ..] => (None, *name),
        };
        self.unit_defs
            .iter()
            .filter(|(name, _)| name.starts_with(prefix))
            .map(|(name, tooltip)| {
                let text = count
                    .map(|count| format!("{count} {name}"))
                    .unwrap_or_else(|| name.clone());
                ChonsoleSuggestion {
                    command: format!("/give {text}"),
                    text,
                    description: format!("Give {name}{tooltip}"),
                }
            })
            .collect()
    }
}

fn builtins() -> Vec<ConsoleCommand> {
    [
        ("help", "List chonsole commands.", false),
        ("echo", "Echo text through the native console.", false),
        ("history", "Show native chonsole input history.", false),
        ("clear", "Clear native chonsole history.", false),
        (
            "autocheat",
            "Toggle automatic /cheat wrapping for cheat-only commands.",
            false,
        ),
        ("a", "Send public chat.", false),
        ("s", "Send spectator chat.", false),
        ("t", "Send ally chat.", false),
        ("texture", "Preview or export an engine texture.", false),
        ("gamerules", "Set a game rules parameter.", true),
        ("teamrules", "Set a team rules parameter.", true),
        (
            "unitrules",
            "Set a rules parameter on selected units.",
            true,
        ),
    ]
    .into_iter()
    .map(|(name, description, requires_cheat)| ConsoleCommand {
        name: name.into(),
        description: description.into(),
        requires_cheat,
    })
    .collect()
}

fn named_values(
    argument: &str,
    command: &str,
    values: &[(String, String)],
) -> Vec<ChonsoleSuggestion> {
    let prefix = argument.split_whitespace().next().unwrap_or("");
    values
        .iter()
        .filter(|(name, _)| name.starts_with(prefix))
        .map(|(name, description)| ChonsoleSuggestion {
            command: format!("{command} {name}"),
            text: name.clone(),
            description: description.clone(),
        })
        .collect()
}

fn rule_values(
    command: &str,
    leading: &[&str],
    prefix: &str,
    values: &[(String, String)],
) -> Vec<ChonsoleSuggestion> {
    let leading = leading.join(" ");
    values
        .iter()
        .filter(|(name, _)| name.starts_with(prefix))
        .map(|(name, value)| ChonsoleSuggestion {
            command: format!("{command} {leading} {name}").trim().to_string(),
            text: name.clone(),
            description: value.clone(),
        })
        .collect()
}

fn score(command: &str, query: &str) -> Option<(u8, usize)> {
    if query.is_empty() {
        return Some((0, command.len()));
    }
    if command.starts_with(query) {
        return Some((0, command.len() - query.len()));
    }
    if let Some(position) = command.find(query) {
        return Some((1, position));
    }
    let mut previous = 0;
    let mut gaps = 0;
    let mut chars = command.char_indices();
    for needle in query.chars() {
        let (index, _) = chars.find(|(_, character)| *character == needle)?;
        gaps += index.saturating_sub(previous);
        previous = index + needle.len_utf8();
    }
    Some((2, gaps))
}
