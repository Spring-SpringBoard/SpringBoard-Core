use spring_native::prelude::NativeInterfaceRef;

use crate::sbc::command_system::command::CommandId;
use crate::sbc::command_system::model::{Model, Models};
use crate::sbc::io::io_api::IoJob;

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
    /// IO jobs queued during `execute`, drained to the IO worker afterwards.
    pub io_jobs: Vec<Box<dyn IoJob>>,
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
            io_jobs: Vec::new(),
            models,
        }
    }

    /// The domain model of type `T` (panics if no feature registered one).
    pub fn model<T: Model>(&mut self) -> &mut T {
        self.models.get::<T>()
    }

    pub fn submit_io(&mut self, job: Box<dyn IoJob>) {
        self.io_jobs.push(job);
    }
}
