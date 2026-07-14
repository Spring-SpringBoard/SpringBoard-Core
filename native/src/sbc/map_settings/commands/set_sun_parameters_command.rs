use log::debug;
use serde::Deserialize;
use spring_native::prelude::sys;

use crate::sbc::command_system::command::Command;
use crate::sbc::command_system::context::Context;
use crate::sbc::command_system::registry::register_command;

/// Sets the sun direction. Execute snapshots the current dir (`Gfx::GetSun("dir")`)
/// on first run for undo, then applies the new one. Runs unsynced (widget state).
#[derive(Deserialize, Debug)]
pub struct SetSunParametersCommand {
    opts: Opts,
    #[serde(skip)]
    old_dir: Option<[f32; 3]>,
}

impl SetSunParametersCommand {
    /// Construct from a partial opts payload (the dir vector). Transitional:
    /// the opts DTO becomes fully typed per docs/porting/todo.md (concrete-commands).
    pub(crate) fn from_opts(opts: serde_json::Value) -> Option<Self> {
        serde_json::from_value(opts).ok().map(|opts| Self {
            opts,
            old_dir: None,
        })
    }
}

#[derive(Deserialize, Debug)]
struct Opts {
    #[serde(rename = "dirX")]
    dir_x: f32,
    #[serde(rename = "dirY")]
    dir_y: f32,
    #[serde(rename = "dirZ")]
    dir_z: f32,
}

impl Command for SetSunParametersCommand {
    fn execute(&mut self, ctx: &mut Context) {
        debug!(
            "SetSunParametersCommand: dir ({}, {}, {})",
            self.opts.dir_x, self.opts.dir_y, self.opts.dir_z
        );
        if self.old_dir.is_none() {
            if let Ok((vals, _count, _, _, _)) = ctx.interface.gfx().get_sun("dir", "") {
                self.old_dir = Some([vals[0], vals[1], vals[2]]);
            }
        }
        apply_dir(ctx, self.opts.dir_x, self.opts.dir_y, self.opts.dir_z);
    }

    fn unexecute(&mut self, ctx: &mut Context) {
        if let Some([x, y, z]) = self.old_dir {
            apply_dir(ctx, x, y, z);
        }
    }
}

fn apply_dir(ctx: &Context, x: f32, y: f32, z: f32) {
    let _ = ctx.interface.unsynced_ctrl().set_sun_direction(
        sys::Float3 { x, y, z },
        // The Lua `SetSunDirection` passes no intensity; keep the engine default.
        1.0,
    );
}

register_command!(SetSunParametersCommand, "SetSunParametersCommand");
