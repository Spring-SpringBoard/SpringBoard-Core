use serde_json::Value;

/// Tag the shader gadget listens for. Deliberately not `command`: that tag is
/// SBC's own command channel, which would try to resolve this as a Lua command
/// class and fail.
pub(crate) const ASSET_SHADER_TAG: &str = "assetShader";

/// Shader parameters the panel drives, sent to the LuaRules gadget that owns the
/// shader. Names match the gadget's uniforms.
pub(crate) struct AssetShaderParams {
    pub asset: String,
    pub enabled: bool,
    pub debug_view: u32,
    pub detail_tile_fine: f32,
    pub detail_tile_coarse: f32,
    pub detail_strength: f32,
    pub roughness_bias: f32,
    pub shadow_density: f32,
    pub shadow_bias: f32,
    pub ambient_scale: f32,
}

impl AssetShaderParams {
    pub(crate) fn to_payload(&self) -> Value {
        serde_json::json!({
            "asset": self.asset,
            "enabled": self.enabled,
            "debugView": self.debug_view,
            "detailTileFine": self.detail_tile_fine,
            "detailTileCoarse": self.detail_tile_coarse,
            "detailStrength": self.detail_strength,
            "roughnessBias": self.roughness_bias,
            "shadowDensity": self.shadow_density,
            "shadowBias": self.shadow_bias,
            "ambientScale": self.ambient_scale,
        })
    }
}
