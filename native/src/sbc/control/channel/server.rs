//! The socket: accept connections, parse a request per line, and hand each to
//! the engine thread. Nothing here touches engine state.

use std::io::{BufRead, BufReader, Write};
use std::net::{TcpListener, TcpStream};
use std::path::PathBuf;
use std::sync::mpsc::{channel, sync_channel, Receiver, Sender, SyncSender};
use std::thread;

use log::{info, warn};
use serde_json::{json, Value};

use super::discovery;
use super::pending::Pending;
use super::protocol::{self, Request, PROTOCOL_VERSION};

pub(crate) struct Job {
    pub request: Request,
    pub reply: SyncSender<String>,
}

pub(crate) struct ControlServer {
    jobs: Receiver<Job>,
    discovery: PathBuf,
    pub(crate) pending: Vec<Pending>,
}

impl ControlServer {
    /// Enabled by `SBC_CONTROL_FILE`, the absolute path of the discovery file to
    /// write. The engine's working directory is not the session write dir, so
    /// the path cannot be derived here.
    pub(crate) fn start() -> Option<ControlServer> {
        let path = PathBuf::from(std::env::var_os("SBC_CONTROL_FILE")?);
        let listener = match TcpListener::bind(("127.0.0.1", 0)) {
            Ok(listener) => listener,
            Err(err) => {
                warn!("control: could not bind loopback socket: {err}");
                return None;
            }
        };
        let port = listener.local_addr().ok()?.port();
        let token = discovery::token();
        let instance_id = discovery::instance_id();

        if let Err(err) = discovery::write(&path, port, &token, &instance_id) {
            warn!("control: could not write {}: {err}", path.display());
            return None;
        }
        info!("control: listening on 127.0.0.1:{port}");

        let (jobs_tx, jobs) = channel();
        thread::spawn(move || accept_loop(listener, jobs_tx, token, instance_id));
        Some(ControlServer {
            jobs,
            discovery: path,
            pending: Vec::new(),
        })
    }

    pub(crate) fn take_jobs(&mut self) -> Vec<Job> {
        self.jobs.try_iter().collect()
    }
}

impl Drop for ControlServer {
    fn drop(&mut self) {
        let _ = std::fs::remove_file(&self.discovery);
    }
}

fn accept_loop(listener: TcpListener, jobs: Sender<Job>, token: String, instance_id: String) {
    for stream in listener.incoming() {
        let Ok(stream) = stream else { continue };
        let jobs = jobs.clone();
        let token = token.clone();
        let instance_id = instance_id.clone();
        thread::spawn(move || {
            if let Err(err) = serve(stream, jobs, &token, &instance_id) {
                warn!("control: connection closed: {err}");
            }
        });
    }
}

/// One connection: parse a request per line, hand it to the engine thread, and
/// block until its reply. Blocking is what keeps a connection's requests
/// applying and answering in order.
fn serve(
    stream: TcpStream,
    jobs: Sender<Job>,
    token: &str,
    instance_id: &str,
) -> std::io::Result<()> {
    let reader = BufReader::new(stream.try_clone()?);
    let mut writer = stream;
    let mut authenticated = false;

    for line in reader.lines() {
        let line = line?;
        if line.trim().is_empty() {
            continue;
        }
        let request: Request = match serde_json::from_str(&line) {
            Ok(request) => request,
            Err(err) => {
                writeln!(
                    writer,
                    "{}",
                    protocol::error(&Value::Null, protocol::INVALID_REQUEST, err.to_string())
                )?;
                continue;
            }
        };

        if !authenticated {
            let offered = request.params.get("token").and_then(Value::as_str);
            if request.method != "authenticate" || offered != Some(token) {
                writeln!(
                    writer,
                    "{}",
                    protocol::error(
                        &request.id,
                        protocol::UNAUTHENTICATED,
                        "authenticate with the token from control.json first",
                    )
                )?;
                continue;
            }
            authenticated = true;
            writeln!(
                writer,
                "{}",
                protocol::result(
                    &request.id,
                    json!({
                        "instance_id": instance_id,
                        "protocol_version": PROTOCOL_VERSION,
                        "pid": std::process::id(),
                    }),
                )
            )?;
            continue;
        }

        let (reply_tx, reply_rx) = sync_channel(1);
        if jobs
            .send(Job {
                request,
                reply: reply_tx,
            })
            .is_err()
        {
            break;
        }
        match reply_rx.recv() {
            Ok(reply) => writeln!(writer, "{reply}")?,
            Err(_) => break,
        }
    }
    Ok(())
}
