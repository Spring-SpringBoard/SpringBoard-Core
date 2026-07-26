use super::completion::{CompletionCatalog, ConsoleCommand};
use crate::sbc::chonsole::framework::{
    ChonsoleLine, ChonsoleLineKind, ChonsoleResponse, ChonsoleSuggestion, MAX_HISTORY,
};

pub struct ChonsoleCore {
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

pub enum ChonsoleEffect {
    Echo(String),
    Chat(ChatTarget, String),
    TextureExport(String),
    RuleCommand {
        scope: RuleScope,
        args: String,
        auto_cheat: bool,
    },
    EngineCommand {
        command: String,
        args: String,
        requires_cheat: bool,
        auto_cheat: bool,
    },
}

pub enum ChatTarget {
    Default,
    Public,
    Ally,
    Spectator,
}

#[derive(Copy, Clone)]
pub enum RuleScope {
    Game,
    Team,
    Unit,
}

/// A command-runtime operation selected by a Chonsole registration.
///
/// This deliberately describes behavior rather than command names: a new
/// registration does not need to modify parsing or dispatch infrastructure.
pub enum ChonsoleAction {
    Empty,
    Help,
    Echo(String),
    History,
    Clear,
    ToggleAutoCheat,
    Chat(ChatTarget, String),
    TextureExport(String),
    RuleCommand {
        scope: RuleScope,
        args: String,
    },
    EngineCommand {
        command: String,
        args: String,
        display: String,
        force_cheat: bool,
    },
}

impl ChonsoleCore {
    pub fn with_history(history: Vec<String>) -> Self {
        let mut core = Self::default();
        for item in history {
            core.push_history(&item);
        }
        core
    }

    pub fn execute(
        &mut self,
        input: &str,
        action: ChonsoleAction,
    ) -> (ChonsoleResponse, Vec<ChonsoleEffect>) {
        let input = input.trim();
        let mut lines = Vec::new();
        let mut effects = Vec::new();
        if input.is_empty() || matches!(action, ChonsoleAction::Empty) {
            return (self.response(input, lines), effects);
        }

        self.push_history(input);
        lines.push(line(ChonsoleLineKind::Input, format!("> {input}")));

        match action {
            ChonsoleAction::Help => {
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
            ChonsoleAction::Echo(text) => {
                effects.push(ChonsoleEffect::Echo(text.clone()));
                lines.push(line(ChonsoleLineKind::Output, text));
            }
            ChonsoleAction::History => {
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
            ChonsoleAction::Clear => {
                self.history.clear();
                lines.push(line(ChonsoleLineKind::Output, "history cleared"));
            }
            ChonsoleAction::ToggleAutoCheat => {
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
            ChonsoleAction::Chat(target, text) => {
                effects.push(ChonsoleEffect::Chat(target, text));
            }
            ChonsoleAction::TextureExport(args) => {
                effects.push(ChonsoleEffect::TextureExport(args));
            }
            ChonsoleAction::RuleCommand { scope, args } => {
                effects.push(ChonsoleEffect::RuleCommand {
                    scope,
                    args,
                    auto_cheat: self.auto_cheat,
                });
            }
            ChonsoleAction::EngineCommand {
                command,
                args,
                display,
                force_cheat,
            } => {
                let requires_cheat = force_cheat || self.catalog.command_requires_cheat(&command);
                effects.push(ChonsoleEffect::EngineCommand {
                    command,
                    args,
                    requires_cheat,
                    auto_cheat: self.auto_cheat,
                });
                lines.push(line(
                    ChonsoleLineKind::Output,
                    format!("sent engine command: /{display}"),
                ));
            }
            ChonsoleAction::Empty => unreachable!("empty actions return before history changes"),
        }

        (self.response(input, lines), effects)
    }

    pub fn suggestions(&self, input: &str) -> Vec<ChonsoleSuggestion> {
        self.catalog.suggestions(input)
    }

    pub fn history(&self) -> &[String] {
        &self.history
    }

    pub fn clear(&mut self) {
        self.history.clear();
    }

    pub fn replace_catalog(&mut self, commands: Vec<ConsoleCommand>) {
        self.catalog.replace_commands(commands);
    }

    pub fn set_local_commands(&mut self, commands: Vec<ConsoleCommand>) {
        self.catalog.set_local_commands(commands);
    }

    pub fn set_game_rules(&mut self, rules: Vec<(String, String)>) {
        self.catalog.set_game_rules(rules);
    }

    pub fn set_textures(&mut self, textures: Vec<String>) {
        self.catalog.set_textures(textures);
    }

    pub fn set_team_rules(&mut self, rules: BTreeMap<i32, Vec<(String, String)>>) {
        self.catalog.set_team_rules(rules);
    }

    pub fn set_unit_rules(&mut self, rules: Vec<(String, String)>) {
        self.catalog.set_unit_rules(rules);
    }

    pub fn set_teams(&mut self, teams: Vec<i32>) {
        self.catalog.set_teams(teams);
    }

    pub fn set_unit_defs(&mut self, definitions: Vec<(String, String)>) {
        self.catalog.set_unit_defs(definitions);
    }

    pub fn set_config_params(&mut self, params: Vec<(String, String)>) {
        self.catalog.set_config_params(params);
    }

    pub fn set_players(&mut self, players: Vec<String>) {
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

fn line(kind: ChonsoleLineKind, text: impl Into<String>) -> ChonsoleLine {
    ChonsoleLine {
        kind,
        text: text.into(),
    }
}

use std::collections::BTreeMap;
