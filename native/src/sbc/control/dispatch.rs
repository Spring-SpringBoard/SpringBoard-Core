//! Requests, applied on the engine thread: deserialize each into its handler's
//! params, route it, and hold back the replies whose effect has not landed.

use serde::de::DeserializeOwned;
use serde_json::json;

use crate::sbc::sbc::SBC;

use super::api::{camera, capture, commands, dialogs, editors, runtime, schema};
use super::channel::{protocol, ControlServer, Effect, Pending, Request};
use super::{ControlError, Handled, Reply};

/// Apply inbound requests before the registered update schedule.
pub(crate) fn begin_update(sbc: &mut SBC) {
    let Some(mut server) = sbc.control.take() else {
        return;
    };
    for job in server.take_jobs() {
        match route(sbc, &job.request) {
            Ok(Reply::Now(value)) => {
                let _ = job.reply.send(protocol::result(&job.request.id, value));
            }
            // Deferred: `resolve_pending` answers it once the effect lands.
            Ok(Reply::When(effect)) => server.pending.push(Pending::new(
                effect,
                job.request.id.clone(),
                job.reply.clone(),
            )),
            Err(err) => {
                let _ = job
                    .reply
                    .send(protocol::error(&job.request.id, err.code, err.message));
            }
        }
    }
    sbc.control = Some(server);
}

/// Resolve deferred requests after the registered update schedule.
///
/// A reply now means the effects of that update have actually been applied,
/// rather than merely that an update is about to start.
pub(crate) fn finish_update(sbc: &mut SBC) {
    let Some(mut server) = sbc.control.take() else {
        return;
    };
    resolve_pending(sbc, &mut server);
    sbc.control = Some(server);
}

fn route(sbc: &mut SBC, request: &Request) -> Handled {
    match request.method.as_str() {
        "describe" => Ok(Reply::now(schema::describe())),
        "ui.open" => editors::open(sbc, params(request)?),
        "ui.set" => editors::set(sbc, params(request)?),
        "ui.get" => editors::get(sbc, params(request)?),
        "command.execute" => commands::execute(sbc, params(request)?),
        "dialog.open" => dialogs::open(sbc, params(request)?),
        "dialog.get" => dialogs::get(sbc, params(request)?),
        "dialog.set" => dialogs::set(sbc, params(request)?),
        "dialog.select" => dialogs::select(sbc, params(request)?),
        "dialog.accept" => dialogs::accept(sbc, params(request)?),
        "dialog.cancel" => dialogs::cancel(sbc, params(request)?),
        "camera.get" => camera::get(sbc),
        "camera.set" => camera::set(sbc, params(request)?),
        "camera.zoom" => camera::zoom(sbc, params(request)?),
        "camera.trace" => camera::trace(sbc, params(request)?),
        "capture" => capture::capture(sbc, params(request)?),
        "runtime.barrier" => runtime::barrier(sbc),
        "runtime.reload_native_modules" => runtime::reload_native_modules(sbc),
        "runtime.reset_session" => runtime::reset_session(sbc),
        other => Err(ControlError::no_such_method(other)),
    }
}

/// The one place params become a handler's own type, so no handler reads raw
/// JSON and a missing or mistyped field is refused before it runs.
fn params<T: DeserializeOwned>(request: &Request) -> Result<T, ControlError> {
    serde_json::from_value(request.params.clone())
        .map_err(|err| ControlError::invalid(format!("{}: {err}", request.method)))
}

/// A reply is only sent once its effect has landed: the editor is open, or the
/// capture is on disk. This is what makes a capture a barrier and lets a client
/// script run without sleeps.
fn resolve_pending(sbc: &mut SBC, server: &mut ControlServer) {
    let mut still_pending = Vec::new();
    for mut pending in std::mem::take(&mut server.pending) {
        let input_idle = match &mut pending.effect {
            Effect::InputIdle {
                observed_input,
                quiet_updates,
            } => {
                if *observed_input != sbc.input_epoch() {
                    *observed_input = sbc.input_epoch();
                    *quiet_updates = 0;
                } else {
                    *quiet_updates = quiet_updates.saturating_add(1);
                }
                Some(*quiet_updates >= 2)
            }
            _ => None,
        };
        let done = if let Some(ready) = input_idle {
            pending.resolve(
                ready,
                || json!({ "advanced": "input-idle" }),
                || "native input did not become idle".to_string(),
            )
        } else {
            match &pending.effect {
                Effect::EditorOpen(editor) => {
                    let editor = *editor;
                    pending.resolve(
                        editors::is_open(sbc, editor),
                        || json!({ "editor": editor }),
                        || format!("editor {editor} did not open"),
                    )
                }
                Effect::DialogOpen(dialog) => {
                    let dialog = *dialog;
                    pending.resolve(
                        sbc.model::<crate::sbc::panels::PanelManager>()
                            .control_dialog_is_open(dialog),
                        || json!({ "dialog": dialog }),
                        || format!("dialog {dialog} did not open"),
                    )
                }
                Effect::DialogClosed(dialog) => {
                    let dialog = *dialog;
                    pending.resolve(
                        !sbc.model::<crate::sbc::panels::PanelManager>()
                            .control_dialog_is_open(dialog),
                        || json!({ "dialog": dialog }),
                        || format!("dialog {dialog} did not close"),
                    )
                }
                Effect::Capture(path) => {
                    let path = path.clone();
                    pending.resolve(
                        path.is_file(),
                        || json!({ "path": path.to_string_lossy() }),
                        || format!("no capture was written to {}", path.display()),
                    )
                }
                Effect::InputIdle { .. } => {
                    unreachable!("handled before borrowing the pending reply")
                }
            }
        };
        if !done {
            still_pending.push(pending);
        }
    }
    server.pending = still_pending;
}
