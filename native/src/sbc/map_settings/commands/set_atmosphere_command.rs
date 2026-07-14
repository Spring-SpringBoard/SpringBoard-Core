use log::debug;
use serde::Deserialize;
use spring_native::prelude::sys;

use crate::sbc::command_system::command::Command;
use crate::sbc::command_system::context::Context;
use crate::sbc::command_system::registry::register_command;

#[derive(Deserialize, Debug)]
pub struct SetAtmosphereCommand {
    opts: Atmosphere,
    #[serde(skip)]
    old: Option<Atmosphere>,
}

impl SetAtmosphereCommand {
    /// Construct from a partial opts payload (one or few fields). Transitional:
    /// the opts DTO becomes fully typed per docs/porting/todo.md (concrete-commands).
    pub(crate) fn from_opts(opts: serde_json::Value) -> Option<Self> {
        serde_json::from_value(opts)
            .ok()
            .map(|opts| Self { opts, old: None })
    }
}

impl Command for SetAtmosphereCommand {
    fn execute(&mut self, ctx: &mut Context) {
        debug!("SetAtmosphereCommand: {:?}", self.opts);
        if self.old.is_none() {
            self.old = Some(self.opts.snapshot(ctx));
        }
        let _ = ctx
            .interface
            .unsynced_ctrl()
            .set_atmosphere(self.opts.to_sys());
    }

    fn unexecute(&mut self, ctx: &mut Context) {
        if let Some(old) = &self.old {
            let _ = ctx.interface.unsynced_ctrl().set_atmosphere(old.to_sys());
        }
    }
}

/// Sets atmosphere (sky/fog) params via `Spring.SetAtmosphere`. Partial opts;
/// undo snapshots via `Gfx::GetAtmosphere`. Runs unsynced (widget state).
#[derive(Deserialize, Debug, Clone, Default)]
pub struct Atmosphere {
    #[serde(default, rename = "fogColor")]
    fog_color: Option<[f32; 4]>,
    #[serde(default, rename = "skyColor")]
    sky_color: Option<[f32; 4]>,
    #[serde(default, rename = "sunColor")]
    sun_color: Option<[f32; 4]>,
    #[serde(default, rename = "cloudColor")]
    cloud_color: Option<[f32; 4]>,
    #[serde(default, rename = "fogStart")]
    fog_start: Option<f32>,
    #[serde(default, rename = "fogEnd")]
    fog_end: Option<f32>,
}

impl Atmosphere {
    fn to_sys(&self) -> sys::AtmosphereParams {
        let mut p: sys::AtmosphereParams = unsafe { std::mem::zeroed() };
        if let Some(c) = self.fog_color {
            p.fogColor = c;
            p.hasFogColor = true;
        }
        if let Some(c) = self.sky_color {
            p.skyColor = c;
            p.hasSkyColor = true;
        }
        if let Some(c) = self.sun_color {
            p.sunColor = c;
            p.hasSunColor = true;
        }
        if let Some(c) = self.cloud_color {
            p.cloudColor = c;
            p.hasCloudColor = true;
        }
        if let Some(v) = self.fog_start {
            p.fogStart = v;
            p.hasFogStart = true;
        }
        if let Some(v) = self.fog_end {
            p.fogEnd = v;
            p.hasFogEnd = true;
        }
        p
    }

    /// Snapshot the keys this command sets (for undo), via `Gfx::GetAtmosphere`.
    fn snapshot(&self, ctx: &Context) -> Atmosphere {
        let gfx = ctx.interface.gfx();
        let color = |key: &str| gfx.get_atmosphere(key, "").ok().map(|(v, ..)| v);
        let scalar = |key: &str| gfx.get_atmosphere(key, "").ok().map(|(v, ..)| v[0]);
        Atmosphere {
            fog_color: self.fog_color.and_then(|_| color("fogColor")),
            sky_color: self.sky_color.and_then(|_| color("skyColor")),
            sun_color: self.sun_color.and_then(|_| color("sunColor")),
            cloud_color: self.cloud_color.and_then(|_| color("cloudColor")),
            fog_start: self.fog_start.and_then(|_| scalar("fogStart")),
            fog_end: self.fog_end.and_then(|_| scalar("fogEnd")),
        }
    }
}

register_command!(SetAtmosphereCommand, "SetAtmosphereCommand");
