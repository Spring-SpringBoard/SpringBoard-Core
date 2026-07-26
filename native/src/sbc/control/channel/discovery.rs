//! The file that advertises the socket: where it is, and the token that proves
//! the client may read the write dir.

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
    restrict(&temp)?;
    std::fs::rename(&temp, path)
}

/// Identifies this run of the editor. A crash leaves the discovery file behind,
/// so a client must check that the session answering is the one advertised.
pub(super) fn instance_id() -> String {
    format!("{}-{}", std::process::id(), nanos())
}

/// Any local process can reach a loopback port, so the token is what limits
/// control to whoever can read the write dir.
pub(super) fn token() -> String {
    #[cfg(unix)]
    {
        use std::io::Read;
        // `/dev/urandom` never reaches EOF, so this must be a bounded read.
        let mut bytes = [0u8; 16];
        if std::fs::File::open("/dev/urandom")
            .and_then(|mut f| f.read_exact(&mut bytes))
            .is_ok()
        {
            return bytes.iter().map(|b| format!("{b:02x}")).collect();
        }
    }
    let seed = nanos() ^ (u128::from(std::process::id()) << 64);
    format!("{seed:032x}")
}

#[cfg(unix)]
fn restrict(path: &Path) -> std::io::Result<()> {
    use std::os::unix::fs::PermissionsExt;
    std::fs::set_permissions(path, std::fs::Permissions::from_mode(0o600))
}

#[cfg(not(unix))]
fn restrict(_path: &Path) -> std::io::Result<()> {
    Ok(())
}

fn nanos() -> u128 {
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map(|d| d.as_nanos())
        .unwrap_or(0)
}
