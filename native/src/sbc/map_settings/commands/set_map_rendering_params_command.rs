use log::debug;
use serde::Deserialize;
use spring_native::prelude::sys;

use crate::sbc::command_system::command::Command;
use crate::sbc::command_system::context::Context;
use crate::sbc::command_system::registry::register_command;

#[derive(Deserialize, Debug)]
pub struct SetMapRenderingParamsCommand {
    opts: MapRendering,
}

impl Command for SetMapRenderingParamsCommand {
    fn execute(&mut self, ctx: &mut Context) {
        debug!("SetMapRenderingParamsCommand: {:?}", self.opts);
        let _ = ctx
            .interface
            .unsynced_ctrl()
            .set_map_rendering_params(self.opts.to_sys());
    }

    fn undoable(&self) -> bool {
        false
    }
}

/// Sets map-rendering params (splat scales/mults, void water/ground) via
/// `Spring.SetMapRenderingParams`. Partial opts. No undo — the Lua command's undo
/// is a FIXME stub, so adding one here would diverge. Runs unsynced (widget state).
#[derive(Deserialize, Debug, Clone, Default)]
struct MapRendering {
    #[serde(default, rename = "splatTexScales")]
    splat_tex_scales: Option<[f32; 4]>,
    #[serde(default, rename = "splatTexMults")]
    splat_tex_mults: Option<[f32; 4]>,
    #[serde(default, rename = "voidWater")]
    void_water: Option<bool>,
    #[serde(default, rename = "voidGround")]
    void_ground: Option<bool>,
    #[serde(default, rename = "splatDetailNormalDiffuseAlpha")]
    splat_detail_normal_diffuse_alpha: Option<bool>,
}

impl MapRendering {
    fn to_sys(&self) -> sys::MapRenderingParams {
        let mut p: sys::MapRenderingParams = unsafe { std::mem::zeroed() };
        if let Some(v) = self.splat_tex_scales {
            p.splatTexScales = v;
            p.hasSplatTexScales = true;
        }
        if let Some(v) = self.splat_tex_mults {
            p.splatTexMults = v;
            p.hasSplatTexMults = true;
        }
        if let Some(v) = self.void_water {
            p.voidWater = v;
            p.hasVoidWater = true;
        }
        if let Some(v) = self.void_ground {
            p.voidGround = v;
            p.hasVoidGround = true;
        }
        if let Some(v) = self.splat_detail_normal_diffuse_alpha {
            p.splatDetailNormalDiffuseAlpha = v;
            p.hasSplatDetailNormalDiffuseAlpha = true;
        }
        p
    }
}

register_command!(SetMapRenderingParamsCommand, "SetMapRenderingParamsCommand");
