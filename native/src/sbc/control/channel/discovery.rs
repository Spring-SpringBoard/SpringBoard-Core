use std::path::Path;
use std::time::{SystemTime, UNIX_EPOCH};

use serde_json::json;

use super::protocol::PROTOCOL_VERSION;

pub(super) fn write(path: &Path, port: u16, token: &str, instance_id: &str) -> std::io::Result<()> {
    if let Some(parent) = path.parent() {
        std::fs::create_dir_all(parent)?;
    }
    let body = json!({
        "host": "127.0.0.1",
        "port": port,
        "token": token,
        "instance_id": instance_id,
        "pid": std::process::id(),
        "protocol_version": PROTOCOL_VERSION,
        "started_at": nanos(),
    });
    let temp = path.with_extension("pending");
    std::fs::write(&temp, body.to_string())?;
    std::fs::rename(&temp, path)
}

pub(super) fn instance_id() -> String {
    format!("{}-{}", std::process::id(), nanos())
}

pub(super) fn token() -> String {
    let mut bytes = [0u8; 16];
    getrandom::fill(&mut bytes).expect("OS CSPRNG unavailable");
    bytes.iter().map(|b| format!("{b:02x}")).collect()
}

fn nanos() -> u128 {
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map(|d| d.as_nanos())
        .unwrap_or(0)
}
