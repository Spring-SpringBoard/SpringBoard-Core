use serde::de::DeserializeOwned;

use crate::sbc::sbc::SBC;

use super::api::{camera, capture, commands, console, runtime, schema};
use super::channel::{pending, protocol, Pending, Request};
use super::input_counter::InputCounter;
use super::{ControlError, Handled, Reply};

pub(crate) fn update(sbc: &mut SBC) {
    let Some(mut server) = sbc.control.take() else {
        return;
    };
    for job in server.take_jobs() {
        match route(sbc, &job.request) {
            Ok(Reply::Now(value)) => {
                let _ = job.reply.send(protocol::result(&job.request.id, value));
            }
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
    let epoch = sbc.model::<InputCounter>().epoch();
    pending::resolve_all(&mut server.pending, epoch);
    sbc.control = Some(server);
}

fn route(sbc: &mut SBC, request: &Request) -> Handled {
    match request.method.as_str() {
        "describe" => Ok(Reply::now(schema::describe())),
        "camera.get" => camera::get(sbc),
        "camera.set" => camera::set(sbc, params(request)?),
        "command.execute" => commands::execute(sbc, params(request)?),
        "console.echo" => console::echo(sbc, params(request)?),
        "capture" => capture::capture(sbc, params(request)?),
        "runtime.barrier" => runtime::barrier(sbc),
        "runtime.reset_session" => runtime::reset_session(sbc),
        "runtime.reload_native_modules" => runtime::reload_native_modules(sbc),
        "runtime.emulate_input" => runtime::emulate_input(sbc, params(request)?),
        other => Err(ControlError::no_such_method(other)),
    }
}

fn params<T: DeserializeOwned>(request: &Request) -> Result<T, ControlError> {
    serde_json::from_value(request.params.clone())
        .map_err(|err| ControlError::invalid(format!("{}: {err}", request.method)))
}
