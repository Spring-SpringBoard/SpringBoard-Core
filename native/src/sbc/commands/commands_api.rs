//! Public surface of the command system. The transport layer parses a payload
//! with [`parse_json_command`], then runs it via [`CommandManager::execute`]
//! with a [`Context`].

pub use crate::sbc::commands::command_system::command_manager::CommandManager;
pub use crate::sbc::commands::command_system::context::Context;
pub use crate::sbc::commands::command_system::registry::parse_json_command;

pub use crate::sbc::commands::heightmap::terrain_manager::TerrainManager;
