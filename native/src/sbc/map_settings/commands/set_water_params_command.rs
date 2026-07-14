use log::debug;
use serde::{Deserialize, Serialize};
use spring_native::prelude::sys;

use crate::sbc::command_system::command::Command;
use crate::sbc::command_system::context::Context;
use crate::sbc::command_system::registry::register_command;

#[derive(Deserialize, Serialize, Debug)]
pub struct SetWaterParamsCommand {
    opts: Water,
    #[serde(skip)]
    old: Option<Water>,
}

impl SetWaterParamsCommand {
    /// Construct from a partial opts payload (one or few fields). Transitional:
    /// the opts DTO becomes fully typed per docs/porting/todo.md (concrete-commands).
    pub(crate) fn from_opts(opts: serde_json::Value) -> Option<Self> {
        serde_json::from_value(opts)
            .ok()
            .map(|opts| Self { opts, old: None })
    }
}

impl Command for SetWaterParamsCommand {
    fn serialize_log(&self) -> serde_json::Value {
        serde_json::to_value(self).unwrap_or(serde_json::Value::Null)
    }

    fn execute(&mut self, ctx: &mut Context) {
        debug!("SetWaterParamsCommand: {:?}", self.opts);
        if self.old.is_none() {
            self.old = Some(snapshot(ctx, &self.opts));
        }
        let _ = ctx
            .interface
            .unsynced_ctrl()
            .set_water_params(self.opts.to_sys());
        self.opts.apply_textures(ctx);
        refresh_water(ctx);
    }

    fn unexecute(&mut self, ctx: &mut Context) {
        if let Some(old) = &self.old {
            let _ = ctx.interface.unsynced_ctrl().set_water_params(old.to_sys());
            old.apply_textures(ctx);
            refresh_water(ctx);
        }
    }
}

/// `set_water_params` updates params but doesn't reload the renderer; re-select
/// the current water mode to force it (mirrors the Lua
/// `SendCommands('water '..GetWaterMode())`).
fn refresh_water(ctx: &Context) {
    if let Ok((mode, _)) = ctx.interface.display().get_water_mode() {
        let _ = ctx
            .interface
            .messages()
            .send_commands("water", &mode.to_string());
    }
}

/// Snapshot the currently-set value of each key present in `opts`, via
/// `Gfx::GetWaterRendering`, so undo restores only what this command changed.
fn snapshot(ctx: &Context, opts: &Water) -> Water {
    let gfx = ctx.interface.gfx();
    let c3 = |present: bool, key: &str| -> Option<[f32; 3]> {
        if !present {
            return None;
        }
        gfx.get_water_rendering(key, "")
            .ok()
            .map(|(v, ..)| [v[0], v[1], v[2]])
    };
    let s1 = |present: bool, key: &str| -> Option<f32> {
        if !present {
            return None;
        }
        gfx.get_water_rendering(key, "").ok().map(|(v, ..)| v[0])
    };
    let tex = |present: bool, key: &str| -> Option<String> {
        if !present {
            return None;
        }
        // Keep the current path even when empty (= no texture): undo must be able
        // to restore "unset", not skip it.
        ctx.interface
            .unsynced_ctrl()
            .get_water_texture(key)
            .ok()
            .flatten()
    };
    let b1 = |present: bool, key: &str| -> Option<bool> {
        if !present {
            return None;
        }
        gfx.get_water_rendering(key, "")
            .ok()
            .map(|(v, ..)| v[0] != 0.0)
    };
    Water {
        absorb: c3(opts.absorb.is_some(), "absorb"),
        base_color: c3(opts.base_color.is_some(), "baseColor"),
        min_color: c3(opts.min_color.is_some(), "minColor"),
        surface_color: c3(opts.surface_color.is_some(), "surfaceColor"),
        diffuse_color: c3(opts.diffuse_color.is_some(), "diffuseColor"),
        specular_color: c3(opts.specular_color.is_some(), "specularColor"),
        plane_color: c3(opts.plane_color.is_some(), "planeColor"),
        repeat_x: s1(opts.repeat_x.is_some(), "repeatX"),
        repeat_y: s1(opts.repeat_y.is_some(), "repeatY"),
        surface_alpha: s1(opts.surface_alpha.is_some(), "surfaceAlpha"),
        ambient_factor: s1(opts.ambient_factor.is_some(), "ambientFactor"),
        diffuse_factor: s1(opts.diffuse_factor.is_some(), "diffuseFactor"),
        specular_factor: s1(opts.specular_factor.is_some(), "specularFactor"),
        specular_power: s1(opts.specular_power.is_some(), "specularPower"),
        fresnel_min: s1(opts.fresnel_min.is_some(), "fresnelMin"),
        fresnel_max: s1(opts.fresnel_max.is_some(), "fresnelMax"),
        fresnel_power: s1(opts.fresnel_power.is_some(), "fresnelPower"),
        reflection_distortion: s1(opts.reflection_distortion.is_some(), "reflectionDistortion"),
        blur_base: s1(opts.blur_base.is_some(), "blurBase"),
        blur_exponent: s1(opts.blur_exponent.is_some(), "blurExponent"),
        perlin_start_freq: s1(opts.perlin_start_freq.is_some(), "perlinStartFreq"),
        perlin_lacunarity: s1(opts.perlin_lacunarity.is_some(), "perlinLacunarity"),
        perlin_amplitude: s1(opts.perlin_amplitude.is_some(), "perlinAmplitude"),
        wind_speed: s1(opts.wind_speed.is_some(), "windSpeed"),
        wave_offset_factor: s1(opts.wave_offset_factor.is_some(), "waveOffsetFactor"),
        wave_length: s1(opts.wave_length.is_some(), "waveLength"),
        wave_foam_distortion: s1(opts.wave_foam_distortion.is_some(), "waveFoamDistortion"),
        wave_foam_intensity: s1(opts.wave_foam_intensity.is_some(), "waveFoamIntensity"),
        caustics_resolution: s1(opts.caustics_resolution.is_some(), "causticsResolution"),
        caustics_strength: s1(opts.caustics_strength.is_some(), "causticsStrength"),
        num_tiles: s1(opts.num_tiles.is_some(), "numTiles"),
        shore_waves: b1(opts.shore_waves.is_some(), "shoreWaves"),
        force_rendering: b1(opts.force_rendering.is_some(), "forceRendering"),
        has_water_plane: b1(opts.has_water_plane.is_some(), "hasWaterPlane"),
        texture: tex(opts.texture.is_some(), "texture"),
        foam_texture: tex(opts.foam_texture.is_some(), "foamTexture"),
        normal_texture: tex(opts.normal_texture.is_some(), "normalTexture"),
    }
}

/// Sets water rendering params (`Spring.SetWaterParams`). Partial opts (the editor
/// sends one key at a time): only present fields apply, undo snapshots them via
/// `Gfx::GetWaterRendering`. Texture-name keys (`texture`/`foamTexture`/
/// `normalTexture`) aren't in `WaterParams`; they apply via the `SetWaterTexture`
/// binding instead. Runs unsynced (widget state) where `Gfx` is valid.
#[derive(Deserialize, Serialize, Debug, Clone, Default)]
struct Water {
    #[serde(default, deserialize_with = "de_color")]
    absorb: Option<[f32; 3]>,
    #[serde(default, rename = "baseColor", deserialize_with = "de_color")]
    base_color: Option<[f32; 3]>,
    #[serde(default, rename = "minColor", deserialize_with = "de_color")]
    min_color: Option<[f32; 3]>,
    #[serde(default, rename = "surfaceColor", deserialize_with = "de_color")]
    surface_color: Option<[f32; 3]>,
    #[serde(default, rename = "diffuseColor", deserialize_with = "de_color")]
    diffuse_color: Option<[f32; 3]>,
    #[serde(default, rename = "specularColor", deserialize_with = "de_color")]
    specular_color: Option<[f32; 3]>,
    #[serde(default, rename = "planeColor", deserialize_with = "de_color")]
    plane_color: Option<[f32; 3]>,

    // Texture paths — Lua sends these as strings. Not part of `WaterParams`;
    // applied via the dedicated `SetWaterTexture` binding in `execute`, and
    // snapshotted for undo via `GetWaterTexture`.
    #[serde(default)]
    texture: Option<String>,
    #[serde(default, rename = "foamTexture")]
    foam_texture: Option<String>,
    #[serde(default, rename = "normalTexture")]
    normal_texture: Option<String>,

    #[serde(default, rename = "repeatX")]
    repeat_x: Option<f32>,
    #[serde(default, rename = "repeatY")]
    repeat_y: Option<f32>,
    #[serde(default, rename = "surfaceAlpha")]
    surface_alpha: Option<f32>,
    #[serde(default, rename = "ambientFactor")]
    ambient_factor: Option<f32>,
    #[serde(default, rename = "diffuseFactor")]
    diffuse_factor: Option<f32>,
    #[serde(default, rename = "specularFactor")]
    specular_factor: Option<f32>,
    #[serde(default, rename = "specularPower")]
    specular_power: Option<f32>,
    #[serde(default, rename = "fresnelMin")]
    fresnel_min: Option<f32>,
    #[serde(default, rename = "fresnelMax")]
    fresnel_max: Option<f32>,
    #[serde(default, rename = "fresnelPower")]
    fresnel_power: Option<f32>,
    #[serde(default, rename = "reflectionDistortion")]
    reflection_distortion: Option<f32>,
    #[serde(default, rename = "blurBase")]
    blur_base: Option<f32>,
    #[serde(default, rename = "blurExponent")]
    blur_exponent: Option<f32>,
    #[serde(default, rename = "perlinStartFreq")]
    perlin_start_freq: Option<f32>,
    #[serde(default, rename = "perlinLacunarity")]
    perlin_lacunarity: Option<f32>,
    #[serde(default, rename = "perlinAmplitude")]
    perlin_amplitude: Option<f32>,
    #[serde(default, rename = "windSpeed")]
    wind_speed: Option<f32>,
    #[serde(default, rename = "waveOffsetFactor")]
    wave_offset_factor: Option<f32>,
    #[serde(default, rename = "waveLength")]
    wave_length: Option<f32>,
    #[serde(default, rename = "waveFoamDistortion")]
    wave_foam_distortion: Option<f32>,
    #[serde(default, rename = "waveFoamIntensity")]
    wave_foam_intensity: Option<f32>,
    #[serde(default, rename = "causticsResolution")]
    caustics_resolution: Option<f32>,
    #[serde(default, rename = "causticsStrength")]
    caustics_strength: Option<f32>,
    #[serde(default, rename = "numTiles")]
    num_tiles: Option<f32>,

    #[serde(default, rename = "shoreWaves")]
    shore_waves: Option<bool>,
    #[serde(default, rename = "forceRendering")]
    force_rendering: Option<bool>,
    #[serde(default, rename = "hasWaterPlane")]
    has_water_plane: Option<bool>,
}

impl Water {
    fn to_sys(&self) -> sys::WaterParams {
        let mut p: sys::WaterParams = unsafe { std::mem::zeroed() };
        // Apply a present optional field and raise its `has*` flag. Works for
        // scalar, `[f32; 3]`, and bool fields alike.
        macro_rules! set {
            ($opt:expr, $field:ident, $has:ident) => {
                if let Some(v) = $opt {
                    p.$field = v;
                    p.$has = true;
                }
            };
        }
        set!(self.absorb, absorb, hasAbsorb);
        set!(self.base_color, baseColor, hasBaseColor);
        set!(self.min_color, minColor, hasMinColor);
        set!(self.surface_color, surfaceColor, hasSurfaceColor);
        set!(self.diffuse_color, diffuseColor, hasDiffuseColor);
        set!(self.specular_color, specularColor, hasSpecularColor);
        set!(self.plane_color, planeColor, hasPlaneColor);
        set!(self.repeat_x, repeatX, hasRepeatX);
        set!(self.repeat_y, repeatY, hasRepeatY);
        set!(self.surface_alpha, surfaceAlpha, hasSurfaceAlpha);
        set!(self.ambient_factor, ambientFactor, hasAmbientFactor);
        set!(self.diffuse_factor, diffuseFactor, hasDiffuseFactor);
        set!(self.specular_factor, specularFactor, hasSpecularFactor);
        set!(self.specular_power, specularPower, hasSpecularPower);
        set!(self.fresnel_min, fresnelMin, hasFresnelMin);
        set!(self.fresnel_max, fresnelMax, hasFresnelMax);
        set!(self.fresnel_power, fresnelPower, hasFresnelPower);
        set!(
            self.reflection_distortion,
            reflectionDistortion,
            hasReflectionDistortion
        );
        set!(self.blur_base, blurBase, hasBlurBase);
        set!(self.blur_exponent, blurExponent, hasBlurExponent);
        set!(self.perlin_start_freq, perlinStartFreq, hasPerlinStartFreq);
        set!(
            self.perlin_lacunarity,
            perlinLacunarity,
            hasPerlinLacunarity
        );
        set!(self.perlin_amplitude, perlinAmplitude, hasPerlinAmplitude);
        set!(self.wind_speed, windSpeed, hasWindSpeed);
        set!(
            self.wave_offset_factor,
            waveOffsetFactor,
            hasWaveOffsetFactor
        );
        set!(self.wave_length, waveLength, hasWaveLength);
        set!(
            self.wave_foam_distortion,
            waveFoamDistortion,
            hasWaveFoamDistortion
        );
        set!(
            self.wave_foam_intensity,
            waveFoamIntensity,
            hasWaveFoamIntensity
        );
        set!(
            self.caustics_resolution,
            causticsResolution,
            hasCausticsResolution
        );
        set!(
            self.caustics_strength,
            causticsStrength,
            hasCausticsStrength
        );
        set!(self.num_tiles, numTiles, hasNumTiles);
        set!(self.shore_waves, shoreWaves, hasShoreWaves);
        set!(self.force_rendering, forceRendering, hasForceRendering);
        set!(self.has_water_plane, hasWaterPlane, hasHasWaterPlane);
        p
    }

    /// Apply texture-path keys via the dedicated `SetWaterTexture` binding (they
    /// aren't representable in the value-typed `WaterParams`). The caller's
    /// `refresh_water` reload is what makes the new textures visible.
    fn apply_textures(&self, ctx: &Context) {
        for (key, path) in [
            ("texture", &self.texture),
            ("foamTexture", &self.foam_texture),
            ("normalTexture", &self.normal_texture),
        ] {
            if let Some(path) = path {
                let _ = ctx.interface.unsynced_ctrl().set_water_texture(key, path);
            }
        }
    }
}

/// Lua `ColorField`s send RGBA (4 floats); the engine's water colors are RGB.
/// Accept 3 or 4 components and keep RGB, so a color change deserializes instead
/// of failing with "invalid length 4, expected fewer elements in array".
fn de_color<'de, D>(d: D) -> Result<Option<[f32; 3]>, D::Error>
where
    D: serde::Deserializer<'de>,
{
    match Option::<Vec<f32>>::deserialize(d)? {
        None => Ok(None),
        Some(v) if v.len() >= 3 => Ok(Some([v[0], v[1], v[2]])),
        Some(v) => Err(serde::de::Error::invalid_length(
            v.len(),
            &"3 or 4 color components",
        )),
    }
}

register_command!(SetWaterParamsCommand, "SetWaterParamsCommand");

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn deserializes_rgba_color_keeping_rgb() {
        // Lua ColorField sends 4 components (RGBA); this used to fail with
        // "invalid length 4, expected fewer elements in array".
        let cmd: SetWaterParamsCommand = serde_json::from_value(serde_json::json!({
            "opts": { "planeColor": [0.1, 0.2, 0.3, 1.0] }
        }))
        .expect("RGBA color should deserialize");
        assert_eq!(cmd.opts.plane_color, Some([0.1, 0.2, 0.3]));
    }

    #[test]
    fn deserializes_rgb_color() {
        let cmd: SetWaterParamsCommand = serde_json::from_value(serde_json::json!({
            "opts": { "diffuseColor": [0.4, 0.5, 0.6] }
        }))
        .expect("RGB color should deserialize");
        assert_eq!(cmd.opts.diffuse_color, Some([0.4, 0.5, 0.6]));
    }

    #[test]
    fn deserializes_texture_path() {
        let cmd: SetWaterParamsCommand = serde_json::from_value(serde_json::json!({
            "opts": { "normalTexture": "maps/foo/normal.png" }
        }))
        .expect("texture path should deserialize");
        assert_eq!(
            cmd.opts.normal_texture.as_deref(),
            Some("maps/foo/normal.png")
        );
    }
}
