use log::debug;
use serde::Deserialize;

use crate::sbc::command_system::command::Command;
use crate::sbc::command_system::context::Context;
use crate::sbc::command_system::registry::register_command;
use crate::sbc::project::ProjectManager;

/// Sets the project name + path (and rewrites name-prefixed mutators). 1:1 with
/// `scen_edit/command/project/set_project_name_path_command.lua`. No undo (the
/// Lua command defines no `unexecute`).
#[derive(Deserialize, Debug)]
pub struct SetProjectNamePathCommand {
    name: String,
    path: String,
}

impl SetProjectNamePathCommand {
    pub(crate) fn new(name: String, path: String) -> Self {
        Self { name, path }
    }
}

impl Command for SetProjectNamePathCommand {
    fn execute(&mut self, ctx: &mut Context) {
        debug!(
            "SetProjectNamePathCommand: name={} path={}",
            self.name, self.path
        );
        ctx.model::<ProjectManager>()
            .set_name_path(&self.name, &self.path);
    }

    fn undoable(&self) -> bool {
        false
    }
}

register_command!(SetProjectNamePathCommand, "SetProjectNamePathCommand");
