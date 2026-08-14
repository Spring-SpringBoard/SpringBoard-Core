use log::{debug, error, info};
use serde::Deserialize;

use spring_native::prelude::*;

use crate::sbc::command_system::command::{Command, CommandId};
use crate::sbc::command_system::model::{Model, Models};
use crate::sbc::commands_api::{parse_json_command, CommandManager, Context};
use crate::sbc::events::EventDispatcher;
use crate::sbc::io::io_api::IoWorker;
use crate::sbc::keys::KeyMods;
use crate::sbc::objects::{event_bridge, ObjectManager};

const MAX_UNDO_SIZE: usize = 100;

pub struct SBC {
    interface: NativeInterfaceRef,
    command_manager: CommandManager,
    models: Models,
    events: EventDispatcher,
    io_worker: IoWorker,
    tests_ran: bool,
}

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
        super::rml::setup(&interface);

        SBC {
            interface,
            command_manager: CommandManager::new(MAX_UNDO_SIZE),
            models: Models::build(interface),
            events: EventDispatcher::new(interface),
            io_worker: IoWorker::new(),
            tests_ran: false,
        }
    }

    fn add_console_line(
        &mut self,
        message: &str,
        section: &str,
        level: i32,
    ) -> Result<bool, Error> {
        let handled = self
            .events
            .add_console_line(&mut self.models, message, section, level)?;
        self.submit_pending_listener_commands();
        Ok(handled)
    }

    fn draw_screen(&mut self, view_size_x: i32, view_size_y: i32) -> Result<(), Error> {
        self.events
            .draw_screen(&mut self.models, view_size_x, view_size_y)
    }

    fn draw_screen_post(&mut self, view_size_x: i32, view_size_y: i32) -> Result<(), Error> {
        self.events
            .draw_screen_post(&mut self.models, view_size_x, view_size_y)
    }

    fn draw_world(&mut self) -> Result<(), Error> {
        self.events.draw_world(&mut self.models)
    }

    fn draw_world_pre_unit(&mut self) -> Result<(), Error> {
        self.events.draw_world_pre_unit(&mut self.models)
    }

    fn handle_lua_call(&mut self, msg: &str) -> Result<(), Error> {
        self.route(msg);
        Ok(())
    }

    #[allow(clippy::too_many_arguments)]
    fn key_press(
        &mut self,
        key_code: i32,
        alt: bool,
        ctrl: bool,
        meta: bool,
        shift: bool,
        is_repeat: bool,
        label: &str,
        utf32_char: i32,
        scan_code: i32,
        _actions: &[KeyAction<'_>],
    ) -> Result<bool, Error> {
        let mods = KeyMods {
            alt,
            ctrl,
            meta,
            shift,
        };
        let handled = self.events.key_press(
            &mut self.models,
            key_code,
            scan_code,
            is_repeat,
            label,
            utf32_char,
            mods,
        )?;
        self.submit_pending_listener_commands();
        Ok(handled)
    }

    #[allow(clippy::too_many_arguments)]
    fn key_release(
        &mut self,
        key_code: i32,
        alt: bool,
        ctrl: bool,
        meta: bool,
        shift: bool,
        label: &str,
        utf32_char: i32,
        scan_code: i32,
        _actions: &[KeyAction<'_>],
    ) -> Result<bool, Error> {
        let mods = KeyMods {
            alt,
            ctrl,
            meta,
            shift,
        };
        let handled = self.events.key_release(
            &mut self.models,
            key_code,
            scan_code,
            label,
            utf32_char,
            mods,
        )?;
        self.submit_pending_listener_commands();
        Ok(handled)
    }

    fn mouse_move(&mut self, x: i32, y: i32, dx: i32, dy: i32, button: i32) -> Result<bool, Error> {
        let handled = self
            .events
            .mouse_move(&mut self.models, x, y, dx, dy, button)?;
        self.submit_pending_listener_commands();
        Ok(handled)
    }

    fn mouse_press(&mut self, x: i32, y: i32, button: i32) -> Result<bool, Error> {
        let handled = self.events.mouse_press(&mut self.models, x, y, button)?;
        self.submit_pending_listener_commands();
        Ok(handled)
    }

    fn mouse_release(&mut self, x: i32, y: i32, button: i32) -> Result<(), Error> {
        self.events.mouse_release(&mut self.models, x, y, button)?;
        self.submit_pending_listener_commands();
        Ok(())
    }

    fn mouse_wheel(&mut self, up: bool, value: f32) -> Result<bool, Error> {
        let handled = self.events.mouse_wheel(&mut self.models, up, value)?;
        self.submit_pending_listener_commands();
        Ok(handled)
    }

    fn text_input(&mut self, utf8: &str) -> Result<bool, Error> {
        let handled = self.events.text_input(&mut self.models, utf8)?;
        self.submit_pending_listener_commands();
        Ok(handled)
    }

    fn update(&mut self, _delta_seconds: f32) -> Result<(), Error> {
        self.drain_io();
        self.events.update(&mut self.models)?;
        self.submit_pending_listener_commands();
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

    pub(crate) fn drain_io(&mut self) {
        for outcome in self.io_worker.drain() {
            outcome.apply(self);
        }
    }

    pub fn model<T: Model>(&mut self) -> &mut T {
        self.models.get::<T>()
    }

    pub fn route(&mut self, msg: &str) {
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

    fn submit_pending_listener_commands(&mut self) {
        let commands = self.events.take_commands(&mut self.models);
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
                self.execute_command(cmd, command_id, &display);
            }
            Ok(None) => {}
            Err(err) => error!("{err}"),
        }
    }

    pub(crate) fn submit_command(&mut self, command: Box<dyn Command>) {
        let id = self.command_manager.allocate_command_id();
        let display = crate::sbc::command_system::registry::class_name_of(&*command)
            .unwrap_or("NativeCommand")
            .to_string();
        log_native_command(&*command, id);
        self.execute_command(command, id, &display);
    }

    fn execute_command(&mut self, command: Box<dyn Command>, id: CommandId, display: &str) {
        self.events.command_recorded(&mut self.models, id, display);
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
        self.events.command_applied(&mut self.models);
        self.models.on_history_events(&history_events);
        self.sync_command_history();
    }

    fn sync_command_history(&mut self) {
        let (undo_ids, redo_ids) = self.command_manager.history_command_ids();
        self.events
            .command_history_changed(&mut self.models, &undo_ids, &redo_ids);
    }
}

fn log_native_command(command: &dyn Command, id: CommandId) {
    let Some(class_name) = crate::sbc::command_system::registry::class_name_of(command) else {
        return;
    };
    let mut data = command.serialize_log();
    if let serde_json::Value::Object(map) = &mut data {
        map.insert("className".to_string(), class_name.into());
        map.insert("__cmd_id".to_string(), id.into());
    } else {
        let mut map = serde_json::Map::new();
        map.insert("className".to_string(), class_name.into());
        map.insert("__cmd_id".to_string(), id.into());
        data = serde_json::Value::Object(map);
    }
    log_command(&serde_json::json!({ "data": data }).to_string());
}

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
