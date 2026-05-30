use spring_native::prelude::NativeInterfaceRef;

/// A command's request back to the manager, applied after `execute` returns so
/// it doesn't access the manager mid-call.
pub enum CommandManagerIntent {
    Undo,
    Redo,
    Clear,
    SetMultipleCommandMode(bool),
}

pub struct Context<'a> {
    #[allow(dead_code)] // first read by slice-1 feature commands
    pub interface: &'a NativeInterfaceRef,
    pub command_manager_intents: Vec<CommandManagerIntent>,
}

impl<'a> Context<'a> {
    pub fn new(interface: &'a NativeInterfaceRef) -> Self {
        Context {
            interface,
            command_manager_intents: Vec::new(),
        }
    }
}
