use log::{debug, error, info};
use serde::Deserialize;

use spring_native::prelude::*;

use crate::sbc::chonsole::ChonsoleManager;
use crate::sbc::command_system::model::{Model, Models};
use crate::sbc::commands_api::{parse_json_command, CommandManager, Context};
use crate::sbc::io::io_api::IoWorker;
use crate::sbc::objects::{event_bridge, ObjectManager};
use crate::sbc::panels::PanelManager;

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
        self.model::<ChonsoleManager>().update()?;
        self.model::<PanelManager>().update()?;
        self.drain_panel_envelopes();
        if !self.tests_ran {
            self.tests_ran = crate::sbc::tests::tests_api::run_if_requested(self);
        }
        Ok(())
    }

    fn draw_screen(&mut self) -> Result<(), Error> {
        self.model::<ChonsoleManager>().draw_screen()?;
        self.model::<PanelManager>().draw_screen()
    }

    fn key_press(&mut self, key_code: i32, scan_code: i32, is_repeat: bool) -> Result<bool, Error> {
        // The panel gets first refusal: while a field is being edited it owns
        // Enter and Escape, which the chonsole would otherwise take (Enter opens
        // it). It consumes nothing else.
        if self
            .model::<PanelManager>()
            .key_press(key_code, scan_code, is_repeat)?
        {
            return Ok(true);
        }
        self.model::<ChonsoleManager>()
            .key_press(key_code, scan_code, is_repeat)
    }

    fn key_release(&mut self, key_code: i32, scan_code: i32) -> Result<bool, Error> {
        if self
            .model::<PanelManager>()
            .key_release(key_code, scan_code)?
        {
            return Ok(true);
        }
        self.model::<ChonsoleManager>()
            .key_release(key_code, scan_code)
    }

    fn text_input(&mut self, utf8: &str) -> Result<bool, Error> {
        if self.model::<PanelManager>().text_input(utf8)? {
            return Ok(true);
        }
        self.model::<ChonsoleManager>().text_input(utf8)
    }

    fn mouse_move(&mut self, x: i32, y: i32, dx: i32, dy: i32, button: i32) -> Result<bool, Error> {
        if self
            .model::<ChonsoleManager>()
            .mouse_move(x, y, dx, dy, button)?
        {
            return Ok(true);
        }
        self.model::<PanelManager>()
            .mouse_move(x, y, dx, dy, button)
    }

    fn mouse_press(&mut self, x: i32, y: i32, button: i32) -> Result<bool, Error> {
        if self.model::<ChonsoleManager>().mouse_press(x, y, button)? {
            return Ok(true);
        }
        self.model::<PanelManager>().mouse_press(x, y, button)
    }

    fn mouse_release(&mut self, x: i32, y: i32, button: i32) -> Result<(), Error> {
        self.model::<ChonsoleManager>()
            .mouse_release(x, y, button)?;
        self.model::<PanelManager>().mouse_release(x, y, button)
    }

    fn mouse_wheel(&mut self, up: bool, value: f32) -> Result<bool, Error> {
        if self.model::<ChonsoleManager>().mouse_wheel(up, value)? {
            return Ok(true);
        }
        self.model::<PanelManager>().mouse_wheel(up, value)
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

    /// Drain queued command envelopes from native panels and route them through
    /// the command system (gives them undo/redo, history events, etc.).
    fn drain_panel_envelopes(&mut self) {
        for envelope in self.model::<PanelManager>().drain_envelopes() {
            self.route(&envelope);
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
            other => {
                if !crate::sbc::message_handler::dispatch(self, other, envelope.data) {
                    error!("Not a command (tag: {other})");
                }
            }
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
                event_bridge::emit(
                    &self.interface,
                    self.models.get::<ObjectManager>().drain_events(),
                );
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

    if let Ok(mut file) = std::fs::OpenOptions::new()
        .create(true)
        .append(true)
        .open(path)
    {
        let now = chrono::Local::now().format("%H:%M:%S%.3f");
        let _ = writeln!(file, "{now} {msg}");
    }
}
