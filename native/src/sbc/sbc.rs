use log::{debug, error, info};
use serde::Deserialize;

use spring_native::prelude::*;

use crate::sbc::commands::commands_api::{
    parse_json_command, CommandManager, Context, TerrainManager,
};
use crate::sbc::io::io_api::IoWorker;

const MAX_UNDO_SIZE: usize = 100;

pub struct SBC {
    interface: NativeInterfaceRef,
    command_manager: CommandManager,

    pub terrain_manager: TerrainManager, // pub: in-engine tests read it directly

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
            terrain_manager: TerrainManager::new(),
            io_worker: IoWorker::new(),
            tests_ran: false,
        }
    }

    fn handle_lua_call(&mut self, msg: &str) -> Result<(), Error> {
        self.route(msg);
        Ok(())
    }

    fn update(&mut self) -> Result<(), Error> {
        for outcome in self.io_worker.drain() {
            outcome.apply(self);
        }
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

    /// Decode the envelope and route by tag. Public so the in-engine test
    /// framework can drive commands the same way Lua does.
    pub fn route(&mut self, msg: &str) {
        // Every command crossing the bridge logs here — set `rust_plugin::sbc`
        // to `debug` (log4rs.yaml) to trace the Lua → Rust path.
        debug!("route({msg})");

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
            Ok(Some(cmd)) => {
                let mut ctx = Context {
                    interface: &self.interface,
                    command_manager_intents: Vec::new(),
                    terrain_manager: &mut self.terrain_manager,
                };
                self.command_manager.execute(cmd, &mut ctx);
            }
            Ok(None) => {}
            Err(err) => error!("{err}"),
        }
    }
}
