use log::debug;
use serde::{Deserialize, Serialize};
use spring_native::prelude::sys;

use crate::sbc::command_system::command::Command;
use crate::sbc::command_system::context::Context;
use crate::sbc::command_system::registry::register_command;

#[derive(Deserialize, Serialize, Debug)]
pub struct SetSunLightingCommand {
    opts: SunLighting,
    #[serde(skip)]
    old: Option<SunLighting>,
}

impl SetSunLightingCommand {
    /// Construct from a partial opts payload (one or few fields). Transitional:
    /// the opts DTO becomes fully typed per docs/porting/todo.md (concrete-commands).
    pub(crate) fn from_opts(opts: serde_json::Value) -> Option<Self> {
        serde_json::from_value(opts)
            .ok()
            .map(|opts| Self { opts, old: None })
    }
}

impl Command for SetSunLightingCommand {
    fn serialize_log(&self) -> serde_json::Value {
        serde_json::to_value(self).unwrap_or(serde_json::Value::Null)
    }

    fn execute(&mut self, ctx: &mut Context) {
        debug!("SetSunLightingCommand: {:?}", self.opts);
        if self.old.is_none() {
            self.old = Some(self.opts.snapshot(ctx));
        }
        let _ = ctx
            .interface
            .unsynced_ctrl()
            .set_sun_lighting(self.opts.to_sys());
    }

    fn unexecute(&mut self, ctx: &mut Context) {
        if let Some(old) = &self.old {
            let _ = ctx.interface.unsynced_ctrl().set_sun_lighting(old.to_sys());
        }
    }
}

/// Sets sun lighting (ground/model ambient/diffuse/specular, shadow densities)
/// via `Spring.SetSunLighting`. Partial opts; undo snapshots via `Gfx::GetSun`
/// (`""` = ground, `"unit"` = model). Wire `unit*` names map to engine `model*`.
/// Runs unsynced (widget state) where `Gfx` is valid.
#[derive(Deserialize, Serialize, Debug, Clone, Default)]
struct SunLighting {
    #[serde(default, rename = "groundAmbientColor")]
    ground_ambient: Option<[f32; 4]>,
    #[serde(default, rename = "groundDiffuseColor")]
    ground_diffuse: Option<[f32; 4]>,
    #[serde(default, rename = "groundSpecularColor")]
    ground_specular: Option<[f32; 4]>,
    #[serde(default, rename = "unitAmbientColor")]
    model_ambient: Option<[f32; 4]>,
    #[serde(default, rename = "unitDiffuseColor")]
    model_diffuse: Option<[f32; 4]>,
    #[serde(default, rename = "unitSpecularColor")]
    model_specular: Option<[f32; 4]>,
    #[serde(default, rename = "groundShadowDensity")]
    ground_shadow_density: Option<f32>,
    #[serde(default, rename = "modelShadowDensity")]
    model_shadow_density: Option<f32>,
}

impl SunLighting {
    fn to_sys(&self) -> sys::SunLightingParams {
        let mut p: sys::SunLightingParams = unsafe { std::mem::zeroed() };
        if let Some(c) = self.ground_ambient {
            p.groundAmbientColor = c;
            p.hasGroundAmbientColor = true;
        }
        if let Some(c) = self.ground_diffuse {
            p.groundDiffuseColor = c;
            p.hasGroundDiffuseColor = true;
        }
        if let Some(c) = self.ground_specular {
            p.groundSpecularColor = c;
            p.hasGroundSpecularColor = true;
        }
        if let Some(c) = self.model_ambient {
            p.modelAmbientColor = c;
            p.hasModelAmbientColor = true;
        }
        if let Some(c) = self.model_diffuse {
            p.modelDiffuseColor = c;
            p.hasModelDiffuseColor = true;
        }
        if let Some(c) = self.model_specular {
            p.modelSpecularColor = c;
            p.hasModelSpecularColor = true;
        }
        if let Some(v) = self.ground_shadow_density {
            p.groundShadowDensity = v;
            p.hasGroundShadowDensity = true;
        }
        if let Some(v) = self.model_shadow_density {
            p.modelShadowDensity = v;
            p.hasModelShadowDensity = true;
        }
        p
    }

    fn snapshot(&self, ctx: &Context) -> SunLighting {
        let gfx = ctx.interface.gfx();
        let color = |key: &str, mode: &str| gfx.get_sun(key, mode).ok().map(|(v, ..)| v);
        let scalar = |key: &str, mode: &str| gfx.get_sun(key, mode).ok().map(|(v, ..)| v[0]);
        SunLighting {
            ground_ambient: self.ground_ambient.and_then(|_| color("ambient", "")),
            ground_diffuse: self.ground_diffuse.and_then(|_| color("diffuse", "")),
            ground_specular: self.ground_specular.and_then(|_| color("specular", "")),
            model_ambient: self.model_ambient.and_then(|_| color("ambient", "unit")),
            model_diffuse: self.model_diffuse.and_then(|_| color("diffuse", "unit")),
            model_specular: self.model_specular.and_then(|_| color("specular", "unit")),
            ground_shadow_density: self
                .ground_shadow_density
                .and_then(|_| scalar("shadowDensity", "")),
            model_shadow_density: self
                .model_shadow_density
                .and_then(|_| scalar("shadowDensity", "unit")),
        }
    }
}

register_command!(SetSunLightingCommand, "SetSunLightingCommand");
