use spring_native::prelude::NativeInterfaceRef;

use crate::sbc::command_system::command::CommandId;
use crate::sbc::command_system::model::{Model, Models};

/// A command's request back to the command manager, applied after `execute`
/// returns so it doesn't re-enter the manager mid-call.
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
    models: &'a mut Models,
}

impl<'a> Context<'a> {
    pub fn new(
        interface: &'a NativeInterfaceRef,
        command_id: CommandId,
        models: &'a mut Models,
    ) -> Self {
        Context {
            interface,
            current_command_id: command_id,
            command_manager_intents: Vec::new(),
            models,
        }
    }

    /// The domain model of type `T` (panics if no feature registered one).
    pub fn model<T: Model>(&mut self) -> &mut T {
        self.models.get::<T>()
    }
}
