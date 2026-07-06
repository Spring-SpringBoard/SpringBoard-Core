use serde::Serialize;

#[derive(Debug, Clone, Serialize, PartialEq, Eq)]
pub struct ChonsoleLine {
    pub kind: ChonsoleLineKind,
    pub text: String,
}

#[derive(Debug, Clone, Copy, Serialize, PartialEq, Eq)]
#[serde(rename_all = "snake_case")]
pub enum ChonsoleLineKind {
    Input,
    Output,
}

#[derive(Debug, Clone, Serialize, PartialEq, Eq)]
pub struct ChonsoleSuggestion {
    pub command: String,
    pub text: String,
    pub description: String,
}

#[derive(Debug, Clone, Serialize, PartialEq, Eq)]
pub struct ChonsoleResponse {
    pub input: String,
    pub lines: Vec<ChonsoleLine>,
    pub history: Vec<String>,
}
