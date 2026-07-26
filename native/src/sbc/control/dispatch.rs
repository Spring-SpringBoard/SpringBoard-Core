//! Requests, applied on the engine thread: deserialize each into its handler's
//! params, route it, and hold back the replies whose effect has not landed.

use serde::de::DeserializeOwned;
use serde_json::json;

use crate::sbc::sbc::SBC;

use super::api::{camera, capture, commands, editors, schema};
use super::channel::{protocol, ControlServer, Effect, Pending, Request};
use super::{ControlError, Handled, Reply};

pub(crate) fn drain(sbc: &mut SBC) {
    let Some(mut server) = sbc.control.take() else {
        return;
    };
    resolve_pending(sbc, &mut server);
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

fn route(sbc: &mut SBC, request: &Request) -> Handled {
    match request.method.as_str() {
        "describe" => Ok(Reply::now(schema::describe())),
        "ui.open" => editors::open(sbc, params(request)?),
        "ui.set" => editors::set(sbc, params(request)?),
        "ui.get" => editors::get(sbc, params(request)?),
        "command.execute" => commands::execute(sbc, params(request)?),
        "camera.get" => camera::get(sbc),
        "camera.set" => camera::set(sbc, params(request)?),
        "capture" => capture::capture(sbc, params(request)?),
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
        let done = match &pending.effect {
            Effect::EditorOpen(editor) => {
                let editor = *editor;
                pending.resolve(
                    editors::is_open(sbc, editor),
                    || json!({ "editor": editor }),
                    || format!("editor {editor} did not open"),
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
        };
        if !done {
            still_pending.push(pending);
        }
    }
    server.pending = still_pending;
}
