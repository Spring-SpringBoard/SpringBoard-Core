use log::{debug, error, info};
use serde::Deserialize;

use spring_native::prelude::*;

use crate::sbc::chonsole::ChonsoleManager;
use crate::sbc::command_system::command::Command;
use crate::sbc::command_system::command::CommandId;
use crate::sbc::command_system::model::{Model, Models};
use crate::sbc::commands_api::{parse_json_command, CommandManager, Context};
use crate::sbc::devconsole::DevConsoleManager;
use crate::sbc::io::io_api::IoWorker;
use crate::sbc::objects::{event_bridge, ObjectKind, ObjectManager, SelectionManager};
use crate::sbc::panels::PanelManager;
use crate::sbc::states::StateManager;

const MAX_UNDO_SIZE: usize = 100;
/// Used when the engine will not report a feature's radius.
const DEFAULT_SELECTION_RADIUS: f32 = 40.0;

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
        self.models
            .with::<PanelManager, _>(|panel, models| panel.update(models))?;
        self.models
            .with::<DevConsoleManager, _>(|console, models| console.update(models))?;
        self.drain_console_commands();
        // The brush the panel edits and the brush the active state paints with
        // are the same; reconcile them before the state paints this tick.
        self.models
            .with::<StateManager, _>(|states, models| -> Result<(), Error> {
                states.sync_brush(models);
                states.update(models)
            })?;
        self.drain_panel_commands();
        self.drain_state_commands();
        if !self.tests_ran {
            self.tests_ran = crate::sbc::tests::tests_api::run_if_requested(self);
        }
        Ok(())
    }

    fn draw_screen(&mut self) -> Result<(), Error> {
        self.model::<StateManager>().draw_screen();
        self.model::<ChonsoleManager>().draw_screen()?;
        self.model::<PanelManager>().draw_screen()
    }

    /// Outline each selected feature. Units glow through the engine's own
    /// selection, and areas draw their own shape, so neither is boxed.
    ///
    /// This is the pre-unit pass so the box is drawn *under* the models, as in
    /// `SelectionManager:DrawWorldPreUnit`.
    fn draw_world_pre_unit(&mut self) -> Result<(), Error> {
        let selected = self.model::<SelectionManager>().all();
        let boxes: Vec<(f32, f32, f32, f32)> = selected
            .into_iter()
            .filter(|(kind, _)| *kind == ObjectKind::Feature)
            .filter_map(|(kind, id)| {
                let objects = self.model::<ObjectManager>();
                let pos = objects.object_pos(kind, id)?;
                let spring_id = objects.spring_id(kind, id)?;
                let radius = self
                    .interface
                    .features()
                    .get_feature_radius(spring_id)
                    .unwrap_or(DEFAULT_SELECTION_RADIUS);
                Some((pos.x, pos.y, pos.z, radius))
            })
            .collect();
        crate::sbc::states::highlight::draw_selected_features(&self.interface, &boxes);
        Ok(())
    }

    fn draw_world(&mut self) -> Result<(), Error> {
        self.model::<StateManager>().draw_world();
        Ok(())
    }

    fn key_press(&mut self, key_code: i32, scan_code: i32, is_repeat: bool) -> Result<bool, Error> {
        // The dev console owns Ctrl+C/Ctrl+A over its text, ahead of the toolbar.
        if self.model::<DevConsoleManager>().text_key(key_code)? {
            return Ok(true);
        }
        // The panel gets first refusal: while a field is being edited it owns
        // Enter and Escape, which the chonsole would otherwise take (Enter opens
        // it). It consumes nothing else.
        if self
            .model::<PanelManager>()
            .key_press(key_code, scan_code, is_repeat)?
        {
            return Ok(true);
        }
        if self.model::<DevConsoleManager>().key_press(key_code)? {
            return Ok(true);
        }
        if self
            .model::<ChonsoleManager>()
            .key_press(key_code, scan_code, is_repeat)?
        {
            return Ok(true);
        }
        // Escape leaves the active editing state.
        let handled = self
            .models
            .with::<StateManager, _>(|s, m| s.key_press(m, key_code))?;
        self.drain_state_commands();
        Ok(handled)
    }

    fn add_console_line(
        &mut self,
        message: &str,
        _section: &str,
        _level: i32,
    ) -> Result<bool, Error> {
        self.model::<DevConsoleManager>().add_console_line(message);
        Ok(false)
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
        if self
            .model::<PanelManager>()
            .mouse_move(x, y, dx, dy, button)?
        {
            return Ok(true);
        }
        // A drag on the map (moving a selected object) is the state's.
        let handled = self
            .models
            .with::<StateManager, _>(|s, m| s.mouse_move(m, x, y, button))?;
        self.drain_state_commands();
        Ok(handled)
    }

    fn mouse_press(&mut self, x: i32, y: i32, button: i32) -> Result<bool, Error> {
        if self.model::<ChonsoleManager>().mouse_press(x, y, button)? {
            return Ok(true);
        }
        if self.model::<PanelManager>().mouse_press(x, y, button)? {
            return Ok(true);
        }
        // Last: a click that reached neither console nor panel is a click on
        // the map, which is the editing state's to interpret.
        let handled = self
            .models
            .with::<StateManager, _>(|s, m| s.mouse_press(m, x, y, button))?;
        self.drain_state_commands();
        Ok(handled)
    }

    fn mouse_release(&mut self, x: i32, y: i32, button: i32) -> Result<(), Error> {
        self.model::<ChonsoleManager>()
            .mouse_release(x, y, button)?;
        self.model::<PanelManager>().mouse_release(x, y, button)?;
        self.models
            .with::<StateManager, _>(|s, m| s.mouse_release(m, x, y, button))?;
        self.drain_state_commands();
        Ok(())
    }

    fn mouse_wheel(&mut self, up: bool, value: f32) -> Result<bool, Error> {
        if self.model::<ChonsoleManager>().mouse_wheel(up, value)? {
            return Ok(true);
        }
        if self.model::<PanelManager>().mouse_wheel(up, value)? {
            return Ok(true);
        }
        self.models
            .with::<StateManager, _>(|s, m| s.mouse_wheel(m, up, value))
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
        self.model::<DevConsoleManager>()
            .record_command(id, display);
        let (history_events, io_jobs) = {
            let mut ctx = Context::new(&self.interface, id, &mut self.models);
            let events = self.command_manager.execute(command, id, &mut ctx);
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
        self.sync_devconsole_command_history();
    }

    /// Drain typed commands queued by native producers and submit them directly
    /// as `Box<dyn Command>` rather than a JSON envelope.
    fn drain_panel_commands(&mut self) {
        for command in self.model::<PanelManager>().drain_commands() {
            self.submit_command(command);
        }
    }

    /// Submit what the active editing state queued. Drained right after each
    /// callin that can produce commands, so a brush stroke's `SetMultipleCommand
    /// ModeCommand(true)` reaches the command manager before the strokes do.
    fn drain_state_commands(&mut self) {
        for command in self.model::<StateManager>().drain_commands() {
            self.submit_command(command);
        }
    }

    fn drain_console_commands(&mut self) {
        for command in self.model::<DevConsoleManager>().drain_commands() {
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
                self.model::<DevConsoleManager>()
                    .record_command(command_id, display);
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
                self.sync_devconsole_command_history();
            }
            Ok(None) => {}
            Err(err) => error!("{err}"),
        }
    }

    fn sync_devconsole_command_history(&mut self) {
        let (undo_ids, redo_ids) = self.command_manager.history_command_ids();
        self.model::<DevConsoleManager>()
            .sync_command_history(&undo_ids, &redo_ids);
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
