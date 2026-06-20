use log::{debug, error, info};
use serde::Deserialize;

use spring_native::prelude::*;

use crate::sbc::command_system::model::{Model, Models};
use crate::sbc::commands_api::{parse_json_command, CommandManager, Context};
use crate::sbc::io::io_api::IoWorker;

const MAX_UNDO_SIZE: usize = 100;

pub struct SBC {
    interface: NativeInterfaceRef,
    command_manager: CommandManager,
    models: Models,
    io_worker: IoWorker,
    tests_ran: bool,
}

/// The `{ tag, data }` envelope Lua sends over `Spring.InvokeNativeModule`.
/// `data` is left as raw JSON — only the command system knows its shape.
#[derive(Deserialize)]
struct Envelope {
    tag: String,
    #[serde(default)]
    data: serde_json::Value,
}

impl NativeModule for SBC {
    fn new(interface: NativeInterfaceRef) -> Self {
        super::log::init(interface);
        info!("SBC logging enabled");

        SBC {
            interface,
            command_manager: CommandManager::new(MAX_UNDO_SIZE),
            models: Models::build(interface),
            io_worker: IoWorker::new(),
            tests_ran: false,
        }
    }

    fn handle_lua_call(&mut self, msg: &str) -> Result<(), Error> {
        self.route(msg);
        Ok(())
    }

    fn update(&mut self) -> Result<(), Error> {
        self.drain_io();
        if !self.tests_ran {
            self.tests_ran = crate::sbc::tests::tests_api::run_if_requested(self);
        }
        Ok(())
    }
}

impl SBC {
    pub fn interface(&self) -> &NativeInterfaceRef {
        &self.interface
    }

    /// Apply any finished background-IO outcomes on the engine thread. Called
    /// each tick; also driven by the in-engine tests while they block the tick.
    pub(crate) fn drain_io(&mut self) {
        for outcome in self.io_worker.drain() {
            outcome.apply(self);
        }
    }

    /// The domain model of type `T`. Used by the in-engine tests to read model
    /// state directly.
    pub fn model<T: Model>(&mut self) -> &mut T {
        self.models.get::<T>()
    }

    /// Decode the envelope and route by tag. Public so the in-engine test
    /// framework can drive commands the same way Lua does.
    pub fn route(&mut self, msg: &str) {
        // Every command crossing the bridge logs here — set `rust_plugin::sbc`
        // to `debug` (log4rs.yaml) to trace the Lua → Rust path.
        debug!("route({msg})");
        log_command(msg);

        let envelope: Envelope = match serde_json::from_str(msg) {
            Ok(e) => e,
            Err(err) => {
                error!("Failed to parse message: {err}. Raw: {msg}");
                return;
            }
        };

        match envelope.tag.as_str() {
            "command" => self.run_command(envelope.data),
            other => error!("Not a command (tag: {other})"),
        }
    }

    fn run_command(&mut self, data: serde_json::Value) {
        match parse_json_command(data) {
            Ok(Some((cmd, command_id))) => {
                let (history_events, io_jobs) = {
                    let mut ctx = Context::new(&self.interface, command_id, &mut self.models);
                    let events = self.command_manager.execute(cmd, command_id, &mut ctx);
                    (events, std::mem::take(&mut ctx.io_jobs))
                };
                for job in io_jobs {
                    self.io_worker.submit(job);
                }
                self.models.on_history_events(&history_events);
            }
            Ok(None) => {}
            Err(err) => error!("{err}"),
        }
    }
}

/// Append every raw command received from Lua to the file named by
/// `$SBC_COMMAND_LOG`, one per line as `HH:MM:SS.mmm <raw json>`. This is a debug
/// trace of exactly what the editor sends (independent of the infolog), useful
/// when a command fails to deserialize. No-op unless the env var is set; the dev
/// launcher points it at `<write_dir>/commands.jsonl`.
fn log_command(msg: &str) {
    use std::io::Write;

    static LOG_PATH: std::sync::OnceLock<Option<std::path::PathBuf>> = std::sync::OnceLock::new();
    let Some(path) = LOG_PATH.get_or_init(|| std::env::var_os("SBC_COMMAND_LOG").map(Into::into))
    else {
        return;
    };

    if let Ok(mut file) = std::fs::OpenOptions::new().create(true).append(true).open(path) {
        let now = chrono::Local::now().format("%H:%M:%S%.3f");
        let _ = writeln!(file, "{now} {msg}");
    }
}
