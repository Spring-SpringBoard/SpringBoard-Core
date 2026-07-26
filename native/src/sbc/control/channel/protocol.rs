use serde::Deserialize;
use serde_json::{json, Value};

pub(crate) const PROTOCOL_VERSION: u32 = 1;

pub(crate) const INVALID_REQUEST: i32 = -32600;
pub(crate) const METHOD_NOT_FOUND: i32 = -32601;
pub(crate) const INVALID_PARAMS: i32 = -32602;
pub(crate) const UNAUTHENTICATED: i32 = -32000;
/// An editor, field or command that does not exist. Distinct from
/// `INVALID_PARAMS` so a client can list what does.
pub(crate) const UNKNOWN_NAME: i32 = -32001;
pub(crate) const FAILED: i32 = -32002;

#[derive(Deserialize)]
pub(crate) struct Request {
    #[serde(default)]
    pub id: Value,
    pub method: String,
    #[serde(default)]
    pub params: Value,
}

pub(crate) fn result(id: &Value, result: Value) -> String {
    json!({ "jsonrpc": "2.0", "id": id, "result": result }).to_string()
}

pub(crate) fn error(id: &Value, code: i32, message: impl Into<String>) -> String {
    let message: String = message.into();
    json!({ "jsonrpc": "2.0", "id": id, "error": { "code": code, "message": message } }).to_string()
}
