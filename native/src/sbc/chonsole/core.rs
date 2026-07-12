use super::completion::CompletionCatalog;
pub(super) use super::completion::ConsoleCommand;
use super::types::{ChonsoleLine, ChonsoleLineKind, ChonsoleResponse, ChonsoleSuggestion};

const MAX_HISTORY: usize = 100;

pub(super) struct ChonsoleCore {
    history: Vec<String>,
    auto_cheat: bool,
    catalog: CompletionCatalog,
}

impl Default for ChonsoleCore {
    fn default() -> Self {
        ChonsoleCore {
            history: Vec::new(),
            auto_cheat: true,
            catalog: CompletionCatalog::default(),
        }
    }
}

pub(super) enum ChonsoleEffect {
    Echo(String),
    Chat(ChatTarget, String),
    EngineCommand {
        command: String,
        args: String,
        requires_cheat: bool,
        auto_cheat: bool,
    },
}

pub(super) enum ChatTarget {
    Default,
    Public,
    Ally,
    Spectator,
}

impl ChonsoleCore {
    pub(super) fn with_history(history: Vec<String>) -> Self {
        let mut core = Self::default();
        for item in history {
            core.push_history(&item);
        }
        core
    }

    pub(super) fn execute(&mut self, input: &str) -> (ChonsoleResponse, Vec<ChonsoleEffect>) {
        let input = input.trim();
        let mut lines = Vec::new();
        let mut effects = Vec::new();
        if input.is_empty() {
            return (self.response(input, lines), effects);
        }

        self.push_history(input);
        lines.push(line(ChonsoleLineKind::Input, format!("> {input}")));

        let parsed = ParsedInput::parse(input);
        match parsed.command.as_str() {
            "help" => {
                for builtin in self.catalog.commands() {
                    lines.push(line(
                        ChonsoleLineKind::Output,
                        format!("/{:<8} {}", builtin.name, builtin.description),
                    ));
                }
                lines.push(line(
                    ChonsoleLineKind::Output,
                    "Commands are discovered from the running Spring engine.".to_string(),
                ));
            }
            "echo" => {
                let text = parsed.args.join(" ");
                effects.push(ChonsoleEffect::Echo(text.clone()));
                lines.push(line(ChonsoleLineKind::Output, text));
            }
            "history" => {
                if self.history.is_empty() {
                    lines.push(line(ChonsoleLineKind::Output, "history is empty"));
                } else {
                    for (idx, item) in self.history.iter().enumerate() {
                        lines.push(line(
                            ChonsoleLineKind::Output,
                            format!("{:>3}: {item}", idx + 1),
                        ));
                    }
                }
            }
            "clear" => {
                self.history.clear();
                lines.push(line(ChonsoleLineKind::Output, "history cleared"));
            }
            "autocheat" => {
                self.auto_cheat = !self.auto_cheat;
                lines.push(line(
                    ChonsoleLineKind::Output,
                    if self.auto_cheat {
                        "AutoCheat enabled"
                    } else {
                        "AutoCheat disabled"
                    },
                ));
            }
            "a" => {
                effects.push(ChonsoleEffect::Chat(
                    ChatTarget::Public,
                    parsed.args.join(" "),
                ));
            }
            "s" => {
                effects.push(ChonsoleEffect::Chat(
                    ChatTarget::Spectator,
                    parsed.args.join(" "),
                ));
            }
            "t" => {
                effects.push(ChonsoleEffect::Chat(
                    ChatTarget::Ally,
                    parsed.args.join(" "),
                ));
            }
            _ => {
                if parsed.is_slash {
                    let requires_cheat = parsed.command == "luarules"
                        && parsed.args.first().is_some_and(|arg| arg == "reload")
                        || self.catalog.command_requires_cheat(&parsed.command);
                    effects.push(ChonsoleEffect::EngineCommand {
                        command: parsed.command.clone(),
                        args: parsed.args.join(" "),
                        requires_cheat,
                        auto_cheat: self.auto_cheat,
                    });
                    lines.push(line(
                        ChonsoleLineKind::Output,
                        format!("sent engine command: /{}", parsed.original_command),
                    ));
                } else {
                    effects.push(ChonsoleEffect::Chat(ChatTarget::Default, input.to_string()));
                }
            }
        }

        (self.response(input, lines), effects)
    }

    pub(super) fn suggestions(&self, input: &str) -> Vec<ChonsoleSuggestion> {
        self.catalog.suggestions(input)
    }

    pub(super) fn history(&self) -> &[String] {
        &self.history
    }

    pub(super) fn clear(&mut self) {
        self.history.clear();
    }

    pub(super) fn replace_catalog(&mut self, commands: Vec<ConsoleCommand>) {
        self.catalog.replace_commands(commands);
    }

    pub(super) fn set_game_rules(&mut self, rules: Vec<(String, String)>) {
        self.catalog.set_game_rules(rules);
    }

    pub(super) fn set_textures(&mut self, textures: Vec<String>) {
        self.catalog.set_textures(textures);
    }

    pub(super) fn set_team_rules(&mut self, rules: BTreeMap<i32, Vec<(String, String)>>) {
        self.catalog.set_team_rules(rules);
    }

    pub(super) fn set_unit_rules(&mut self, rules: Vec<(String, String)>) {
        self.catalog.set_unit_rules(rules);
    }

    pub(super) fn set_teams(&mut self, teams: Vec<i32>) {
        self.catalog.set_teams(teams);
    }

    pub(super) fn set_unit_defs(&mut self, definitions: Vec<(String, String)>) {
        self.catalog.set_unit_defs(definitions);
    }

    pub(super) fn set_config_params(&mut self, params: Vec<(String, String)>) {
        self.catalog.set_config_params(params);
    }

    pub(super) fn set_players(&mut self, players: Vec<String>) {
        self.catalog.set_players(players);
    }

    fn push_history(&mut self, input: &str) {
        if self.history.last().is_some_and(|last| last == input) {
            return;
        }
        self.history.push(input.to_string());
        if self.history.len() > MAX_HISTORY {
            self.history.remove(0);
        }
    }

    fn response(&self, input: &str, lines: Vec<ChonsoleLine>) -> ChonsoleResponse {
        ChonsoleResponse {
            input: input.to_string(),
            lines,
            history: self.history.clone(),
        }
    }
}

#[derive(Debug, Clone)]
struct ParsedInput {
    is_slash: bool,
    command: String,
    original_command: String,
    args: Vec<String>,
}

impl ParsedInput {
    fn parse(input: &str) -> Self {
        let is_slash = input.starts_with('/');
        let stripped = input.strip_prefix('/').unwrap_or(input).trim();
        let mut parts = stripped.split_whitespace();
        let original_command = parts.next().unwrap_or("").to_string();
        let command = original_command.to_ascii_lowercase();
        let args = parts.map(ToString::to_string).collect();
        ParsedInput {
            is_slash,
            command,
            original_command: stripped.to_string(),
            args,
        }
    }
}

fn line(kind: ChonsoleLineKind, text: impl Into<String>) -> ChonsoleLine {
    ChonsoleLine {
        kind,
        text: text.into(),
    }
}

use std::collections::BTreeMap;
