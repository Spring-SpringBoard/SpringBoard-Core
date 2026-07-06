use super::types::{ChonsoleLine, ChonsoleLineKind, ChonsoleResponse, ChonsoleSuggestion};

const MAX_HISTORY: usize = 100;

#[derive(Debug, Clone)]
struct ConsoleCommand {
    name: &'static str,
    description: &'static str,
    native: bool,
    requires_cheat: bool,
}

const COMMANDS: &[ConsoleCommand] = &[
    ConsoleCommand {
        name: "help",
        description: "List native chonsole commands.",
        native: true,
        requires_cheat: false,
    },
    ConsoleCommand {
        name: "echo",
        description: "Echo text through the native console.",
        native: true,
        requires_cheat: false,
    },
    ConsoleCommand {
        name: "history",
        description: "Show native chonsole input history.",
        native: true,
        requires_cheat: false,
    },
    ConsoleCommand {
        name: "clear",
        description: "Clear native chonsole history.",
        native: true,
        requires_cheat: false,
    },
    ConsoleCommand {
        name: "autocheat",
        description: "Toggle automatic /cheat wrapping for cheat-only commands.",
        native: true,
        requires_cheat: false,
    },
    ConsoleCommand {
        name: "a",
        description: "Send public chat.",
        native: true,
        requires_cheat: false,
    },
    ConsoleCommand {
        name: "s",
        description: "Send spectator chat.",
        native: true,
        requires_cheat: false,
    },
    ConsoleCommand {
        name: "t",
        description: "Send ally chat.",
        native: true,
        requires_cheat: false,
    },
    ConsoleCommand {
        name: "cheat",
        description: "Forward cheat toggle to the Spring engine.",
        native: false,
        requires_cheat: false,
    },
    ConsoleCommand {
        name: "give",
        description: "Forward unit spawn command to the Spring engine.",
        native: false,
        requires_cheat: true,
    },
    ConsoleCommand {
        name: "gamerules",
        description: "Forward game rules-param command to the Spring engine.",
        native: false,
        requires_cheat: true,
    },
    ConsoleCommand {
        name: "globallos",
        description: "Forward global line-of-sight toggle to the Spring engine.",
        native: false,
        requires_cheat: true,
    },
    ConsoleCommand {
        name: "godmode",
        description: "Forward god mode toggle to the Spring engine.",
        native: false,
        requires_cheat: true,
    },
    ConsoleCommand {
        name: "luarules",
        description: "Forward LuaRules command to the Spring engine.",
        native: false,
        requires_cheat: false,
    },
    ConsoleCommand {
        name: "luaui",
        description: "Forward LuaUI command to the Spring engine.",
        native: false,
        requires_cheat: false,
    },
    ConsoleCommand {
        name: "nocost",
        description: "Forward no-cost toggle to the Spring engine.",
        native: false,
        requires_cheat: true,
    },
    ConsoleCommand {
        name: "set",
        description: "Forward config command to the Spring engine.",
        native: false,
        requires_cheat: false,
    },
    ConsoleCommand {
        name: "spectator",
        description: "Forward spectator command to the Spring engine.",
        native: false,
        requires_cheat: false,
    },
    ConsoleCommand {
        name: "team",
        description: "Forward team switch command to the Spring engine.",
        native: false,
        requires_cheat: false,
    },
    ConsoleCommand {
        name: "teamrules",
        description: "Forward team rules-param command to the Spring engine.",
        native: false,
        requires_cheat: true,
    },
    ConsoleCommand {
        name: "unitrules",
        description: "Forward unit rules-param command to the Spring engine.",
        native: false,
        requires_cheat: true,
    },
    ConsoleCommand {
        name: "water",
        description: "Forward water rendering command to the Spring engine.",
        native: false,
        requires_cheat: false,
    },
    ConsoleCommand {
        name: "w",
        description: "Forward chat message command to the Spring engine.",
        native: false,
        requires_cheat: false,
    },
];

pub(super) struct ChonsoleCore {
    history: Vec<String>,
    auto_cheat: bool,
}

impl Default for ChonsoleCore {
    fn default() -> Self {
        ChonsoleCore {
            history: Vec::new(),
            auto_cheat: true,
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
                for builtin in COMMANDS.iter().filter(|cmd| cmd.native) {
                    lines.push(line(
                        ChonsoleLineKind::Output,
                        format!("/{:<8} {}", builtin.name, builtin.description),
                    ));
                }
                lines.push(line(
                    ChonsoleLineKind::Output,
                    "Other slash commands are passed through to the Spring engine.".to_string(),
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
                    let requires_cheat = command_requires_cheat(&parsed);
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
        let trimmed = input.trim_start();
        let prefix = trimmed
            .strip_prefix('/')
            .unwrap_or(trimmed)
            .split_whitespace()
            .next()
            .unwrap_or("");
        let prefix = prefix.to_ascii_lowercase();
        let mut scored = COMMANDS
            .iter()
            .filter_map(|cmd| {
                let score = suggestion_score(cmd.name, &prefix)?;
                Some((score, cmd))
            })
            .collect::<Vec<_>>();
        scored.sort_by_key(|(score, cmd)| (*score, cmd.name));
        scored
            .into_iter()
            .map(|(_, cmd)| ChonsoleSuggestion {
                command: format!("/{}", cmd.name),
                text: cmd.name.to_string(),
                description: cmd.description.to_string(),
            })
            .collect()
    }

    pub(super) fn history(&self) -> &[String] {
        &self.history
    }

    pub(super) fn clear(&mut self) {
        self.history.clear();
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

fn suggestion_score(command: &str, query: &str) -> Option<(u8, usize)> {
    if query.is_empty() {
        return Some((0, command.len()));
    }
    if command.starts_with(query) {
        return Some((0, command.len() - query.len()));
    }
    if let Some(pos) = command.find(query) {
        return Some((1, pos));
    }

    let mut last = 0usize;
    let mut gap_score = 0usize;
    let mut chars = command.char_indices();
    for q in query.chars() {
        let (idx, _) = chars.find(|(_, c)| *c == q)?;
        gap_score += idx.saturating_sub(last);
        last = idx + q.len_utf8();
    }
    Some((2, gap_score))
}

fn command_requires_cheat(parsed: &ParsedInput) -> bool {
    if parsed.command == "luarules" && parsed.args.first().is_some_and(|arg| arg == "reload") {
        return true;
    }
    COMMANDS
        .iter()
        .find(|cmd| cmd.name == parsed.command)
        .is_some_and(|cmd| cmd.requires_cheat)
}
