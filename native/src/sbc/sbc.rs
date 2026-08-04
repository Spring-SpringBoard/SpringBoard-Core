use log::{debug, error, info};
use serde::Deserialize;

use spring_native::prelude::*;

use crate::sbc::command_system::command::Command;
use crate::sbc::command_system::command::CommandId;
use crate::sbc::command_system::model::{Model, Models};
use crate::sbc::command_system::UndoCommand;
use crate::sbc::commands_api::{parse_json_command, CommandManager, Context};
use crate::sbc::control::ControlServer;
use crate::sbc::events::EventDispatcher;
use crate::sbc::io::io_api::IoWorker;
use crate::sbc::keys::KeyMods;

const MAX_UNDO_SIZE: usize = 100;

pub struct SBC {
    interface: NativeInterfaceRef,
    command_manager: CommandManager,
    models: Models,
    events: EventDispatcher,
    io_worker: IoWorker,
    tests_ran: bool,
    input_epoch: u64,
    /// The machine-facing control channel, when `SBC_CONTROL_FILE` asked for
    /// one. Taken out of `self` while its requests are handled, since they
    /// operate on everything else here.
    pub(crate) control: Option<ControlServer>,
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
            events: EventDispatcher::new(interface),
            io_worker: IoWorker::new(),
            tests_ran: false,
            input_epoch: 0,
            control: ControlServer::start(),
        }
    }

    fn handle_lua_call(&mut self, msg: &str) -> Result<(), Error> {
        self.route(msg);
        Ok(())
    }

    fn update(&mut self, _delta_seconds: f32) -> Result<(), Error> {
        self.drain_io();
        // Incoming controls apply before the schedule; their deferred replies
        // resolve after it, once the requested update effects have landed.
        crate::sbc::control::begin_update(self);
        let mut update = self.events.begin_update();
        while let Some(commands) = self.events.run_update_step(&mut self.models, &mut update)? {
            self.submit_commands(commands);
        }
        crate::sbc::control::finish_update(self);
        if !self.tests_ran {
            self.tests_ran = crate::sbc::tests::tests_api::run_if_requested(self);
        }
        Ok(())
    }

    fn draw_screen(&mut self, _view_size_x: i32, _view_size_y: i32) -> Result<(), Error> {
        self.events.draw_screen(&mut self.models)
    }

    fn draw_screen_post(&mut self, _view_size_x: i32, _view_size_y: i32) -> Result<(), Error> {
        self.events.draw_screen_post(&mut self.models)
    }

    /// Feature overlays register for this pre-unit phase so they draw under
    /// engine models.
    fn draw_world_pre_unit(&mut self) -> Result<(), Error> {
        self.events.draw_world_pre_unit(&mut self.models)
    }

    fn draw_world(&mut self) -> Result<(), Error> {
        self.events.draw_world(&mut self.models)
    }

    #[allow(clippy::too_many_arguments)]
    fn key_press(
        &mut self,
        key_code: i32,
        _alt: bool,
        ctrl: bool,
        _meta: bool,
        shift: bool,
        is_repeat: bool,
        _label: &str,
        _utf32_char: i32,
        scan_code: i32,
        _actions: &[KeyAction<'_>],
    ) -> Result<bool, Error> {
        self.note_input();
        let mods = KeyMods { ctrl, shift };
        let handled =
            self.events
                .key_press(&mut self.models, key_code, scan_code, is_repeat, mods)?;
        self.submit_pending_listener_commands();
        Ok(handled)
    }

    fn add_console_line(
        &mut self,
        message: &str,
        _section: &str,
        level: i32,
    ) -> Result<bool, Error> {
        self.events.console_line(&mut self.models, message, level)
    }

    #[allow(clippy::too_many_arguments)]
    fn key_release(
        &mut self,
        key_code: i32,
        _alt: bool,
        ctrl: bool,
        _meta: bool,
        shift: bool,
        _label: &str,
        _utf32_char: i32,
        scan_code: i32,
        _actions: &[KeyAction<'_>],
    ) -> Result<bool, Error> {
        self.note_input();
        let mods = KeyMods { ctrl, shift };
        self.events
            .key_release(&mut self.models, key_code, scan_code, mods)
    }

    fn text_input(&mut self, utf8: &str) -> Result<bool, Error> {
        self.note_input();
        self.events.text_input(&mut self.models, utf8)
    }

    fn mouse_move(&mut self, x: i32, y: i32, dx: i32, dy: i32, button: i32) -> Result<bool, Error> {
        self.note_input();
        let handled = self
            .events
            .mouse_move(&mut self.models, x, y, dx, dy, button)?;
        self.submit_pending_listener_commands();
        Ok(handled)
    }

    fn mouse_press(&mut self, x: i32, y: i32, button: i32) -> Result<bool, Error> {
        self.note_input();
        let handled = self.events.mouse_press(&mut self.models, x, y, button)?;
        self.submit_pending_listener_commands();
        Ok(handled)
    }

    fn mouse_release(&mut self, x: i32, y: i32, button: i32) -> Result<(), Error> {
        self.note_input();
        self.events.mouse_release(&mut self.models, x, y, button)?;
        self.submit_pending_listener_commands();
        Ok(())
    }

    fn mouse_wheel(&mut self, up: bool, value: f32) -> Result<bool, Error> {
        self.note_input();
        self.events.mouse_wheel(&mut self.models, up, value)
    }
}

impl SBC {
    pub fn interface(&self) -> &NativeInterfaceRef {
        &self.interface
    }

    pub(crate) fn input_epoch(&self) -> u64 {
        self.input_epoch
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

    /// The whole model registry. In-engine tests use this to drive the action
    /// layer, which operates on several models at once.
    pub(crate) fn models_mut(&mut self) -> &mut Models {
        &mut self.models
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

    /// Submit a command produced natively (no JSON envelope, no `className`).
    /// The command manager allocates the id; this is the typed counterpart to
    /// `run_command`, which serves the Lua/envelope path. Logging is centralized
    /// here so the e2e command log captures native commands without each
    /// producer building JSON for it.
    pub(crate) fn submit_command(&mut self, command: Box<dyn Command>) {
        let id = self.command_manager.allocate_command_id();
        let display = crate::sbc::command_system::registry::class_name_of(&*command)
            .unwrap_or("NativeCommand")
            .to_string();
        log_native_command(&*command, id);
        self.events.command_recorded(&mut self.models, id, &display);
        let (history_events, io_jobs) = {
            let mut ctx = Context::new(&self.interface, id, &mut self.models);
            let events = self.command_manager.execute(command, id, &mut ctx);
            (events, std::mem::take(&mut ctx.io_jobs))
        };
        for job in io_jobs {
            self.io_worker.submit(job);
        }
        self.events.command_applied(&mut self.models);
        self.models.on_history_events(&history_events);
        self.sync_command_history();
    }

    /// Restore the native command state to its pre-edit baseline. This is a
    /// session-boundary primitive for the control channel, not a user-facing
    /// action: every undoable native command is undone in history order.
    pub(crate) fn undo_all(&mut self) -> Result<usize, String> {
        let mut undone = 0;
        while self.command_manager.undo_depth() > 0 {
            if self.command_manager.is_streaming() {
                return Err("cannot undo all while a streaming command is active".to_string());
            }
            let before = self.command_manager.undo_depth();
            self.submit_command(Box::new(UndoCommand));
            if self.command_manager.undo_depth() >= before {
                return Err("undo command did not advance the history cursor".to_string());
            }
            undone += 1;
        }
        Ok(undone)
    }

    fn note_input(&mut self) {
        self.input_epoch = self.input_epoch.wrapping_add(1);
    }

    /// Submit commands gathered from registered event listeners. Producers only
    /// queue typed commands; the module boundary owns their execution.
    fn submit_pending_listener_commands(&mut self) {
        let commands = self.events.take_commands();
        self.submit_commands(commands);
    }

    fn submit_commands(&mut self, commands: Vec<Box<dyn Command>>) {
        for command in commands {
            self.submit_command(command);
        }
    }

    fn run_command(&mut self, data: serde_json::Value) {
        let display = data
            .get("className")
            .and_then(serde_json::Value::as_str)
            .unwrap_or("Command")
            .to_string();
        match parse_json_command(data) {
            Ok(Some((cmd, command_id))) => {
                self.events
                    .command_recorded(&mut self.models, command_id, &display);
                let (history_events, io_jobs) = {
                    let mut ctx = Context::new(&self.interface, command_id, &mut self.models);
                    let events = self.command_manager.execute(cmd, command_id, &mut ctx);
                    (events, std::mem::take(&mut ctx.io_jobs))
                };
                for job in io_jobs {
                    self.io_worker.submit(job);
                }
                self.events.command_applied(&mut self.models);
                self.models.on_history_events(&history_events);
                self.sync_command_history();
            }
            Ok(None) => {}
            Err(err) => error!("{err}"),
        }
    }

    fn sync_command_history(&mut self) {
        let (undo_ids, redo_ids) = self.command_manager.history_command_ids();
        self.events
            .command_history_changed(&mut self.models, &undo_ids, &redo_ids);
    }
}

/// Log a native command to `commands.jsonl` in the envelope shape the e2e suite
/// parses: `{data: {className, __cmd_id, ...serialized fields}}`. The className
/// comes from the registry's `TypeId` map; the fields come from `Serialize`.
fn log_native_command(command: &dyn Command, id: CommandId) {
    let Some(class_name) = crate::sbc::command_system::registry::class_name_of(command) else {
        return;
    };
    let mut data = command.serialize_log();
    if let serde_json::Value::Object(map) = &mut data {
        map.insert("className".to_string(), class_name.into());
        map.insert("__cmd_id".to_string(), id.into());
        if command.is_preview() {
            map.insert("__preview".to_string(), true.into());
        }
    } else {
        // Unit structs / default `Null`: log className + id with no fields.
        let mut preview = serde_json::Map::new();
        preview.insert("className".to_string(), class_name.into());
        preview.insert("__cmd_id".to_string(), id.into());
        if command.is_preview() {
            preview.insert("__preview".to_string(), true.into());
        }
        data = serde_json::Value::Object(preview);
    }
    log_command(&serde_json::json!({ "data": data }).to_string());
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
