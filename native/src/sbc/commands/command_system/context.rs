use spring_native::prelude::NativeInterfaceRef;

use crate::sbc::commands::command_system::command::CommandId;
use crate::sbc::commands::heightmap::terrain_manager::TerrainManager;

/// A command's request back to the manager, applied after `execute` returns so
/// it doesn't access the manager mid-call.
pub enum CommandManagerIntent {
    Undo,
    Redo,
    Clear,
    SetMultipleCommandMode(bool),
}

pub struct Context<'a> {
    pub interface: &'a NativeInterfaceRef,
    pub current_command_id: CommandId,
    pub command_manager_intents: Vec<CommandManagerIntent>,

    pub terrain_manager: &'a mut TerrainManager,
}
