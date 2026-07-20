//! Uploading the engine infolog to logs.springrts.com, reproducing what the
//! launcher's "Upload Log" button did — without the launcher.
//!
//! The plugin carries no HTTP client, so the POST is delegated to `curl` (the
//! same shell-out approach the map compiler uses for its external tools). It
//! runs on the IO thread since it blocks on the network, and reports the
//! resulting URL — copied to the clipboard — through a toast.

use std::io::Write;
use std::path::PathBuf;
use std::process::{Command as OsCommand, Stdio};

use serde::Deserialize;
use serde_json::json;

use crate::sbc::command_system::command::Command;
use crate::sbc::command_system::context::Context;
use crate::sbc::command_system::io_completion;
use crate::sbc::command_system::registry::register_command;
use crate::sbc::io::io_api::{IoJob, IoOutcome};
use crate::sbc::notifications::NotificationManager;
use crate::sbc::sbc::SBC;

const UPLOAD_URL: &str = "http://logs.springrts.com/logfiles/";

/// Queues the log upload as background IO. Not serialized from Lua; constructed
/// directly by the status bar.
#[derive(Deserialize, Debug)]
pub struct UploadLogCommand {
    #[serde(skip)]
    log_path: PathBuf,
}

impl UploadLogCommand {
    pub(crate) fn new(log_path: PathBuf) -> Self {
        Self { log_path }
    }
}

impl Command for UploadLogCommand {
    fn execute(&mut self, ctx: &mut Context) {
        ctx.submit_io(Box::new(UploadLogJob {
            log_path: std::mem::take(&mut self.log_path),
        }));
        io_completion::submit_native_command_completed(ctx);
    }

    fn undoable(&self) -> bool {
        false
    }
}

struct UploadLogJob {
    log_path: PathBuf,
}

impl IoJob for UploadLogJob {
    fn run(self: Box<Self>) -> Box<dyn IoOutcome> {
        Box::new(match upload(&self.log_path) {
            Ok(url) => UploadLogOutcome::Done { url },
            Err(reason) => UploadLogOutcome::Failed { reason },
        })
    }
}

enum UploadLogOutcome {
    Done { url: String },
    Failed { reason: String },
}

impl IoOutcome for UploadLogOutcome {
    fn apply(self: Box<Self>, sbc: &mut SBC) {
        match *self {
            UploadLogOutcome::Done { url } => {
                let _ = sbc.interface().unsynced_ctrl().set_clipboard(&url);
                sbc.model::<NotificationManager>().info(
                    "upload-log",
                    "Log uploaded",
                    &format!("{url} (copied to clipboard)"),
                );
            }
            UploadLogOutcome::Failed { reason } => {
                log::error!("log upload failed: {reason}");
                sbc.model::<NotificationManager>()
                    .warn("upload-log", &format!("Log upload failed: {reason}"));
            }
        }
    }
}

fn upload(log_path: &PathBuf) -> Result<String, String> {
    let text = std::fs::read_to_string(log_path)
        .map_err(|err| format!("cannot read {}: {err}", log_path.display()))?;
    let body = json!({
        "name": "SpringBoard log",
        "text": text,
        "tags": ["springboard", "native"],
    })
    .to_string();

    let mut child = OsCommand::new("curl")
        .args([
            "--silent",
            "--show-error",
            "--max-time",
            "30",
            "-H",
            "Content-Type: application/json",
            "--data-binary",
            "@-",
            UPLOAD_URL,
        ])
        .stdin(Stdio::piped())
        .stdout(Stdio::piped())
        .stderr(Stdio::piped())
        .spawn()
        .map_err(|err| format!("could not run curl: {err}"))?;

    child
        .stdin
        .take()
        .ok_or("curl stdin unavailable")?
        .write_all(body.as_bytes())
        .map_err(|err| format!("writing to curl: {err}"))?;

    let output = child
        .wait_with_output()
        .map_err(|err| format!("curl did not complete: {err}"))?;
    if !output.status.success() {
        return Err(format!(
            "curl exited with {}: {}",
            output.status,
            String::from_utf8_lossy(&output.stderr).trim()
        ));
    }

    let response = String::from_utf8_lossy(&output.stdout);
    let parsed: UploadResponse =
        serde_json::from_str(response.trim()).map_err(|err| format!("unexpected reply: {err}"))?;
    // The service returns http; the launcher rewrites it to https for sharing.
    Ok(parsed.url.replacen("http://", "https://", 1))
}

#[derive(Deserialize)]
struct UploadResponse {
    url: String,
}

register_command!(UploadLogCommand, "UploadLogCommand");
