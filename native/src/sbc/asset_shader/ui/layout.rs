use crate::sbc::panels::runtime::Item;

use super::model::AssetShaderField;
use super::model::AssetShaderField::*;

pub(crate) fn layout(preview: &str) -> Vec<Item<AssetShaderField>> {
    vec![
        Item::Field(Enabled),
        Item::Section("Debug"),
        Item::Field(DebugView),
        Item::Section("Maps"),
        Item::Field(PreviewMap),
        Item::Custom(preview_markup(preview)),
        Item::Section("Detail"),
        Item::Row(&[DetailTileFine, DetailTileCoarse]),
        Item::Field(DetailStrength),
        Item::Section("Shading"),
        Item::Row(&[RoughnessBias, ShadowDensity]),
        Item::Field(ShadowBias),
        Item::Field(AmbientScale),
    ]
}

/// Missing textures render as an empty box rather than an error, so an asset that
/// has not been packaged yet still opens the panel.
fn preview_markup(path: &str) -> String {
    if path.is_empty() {
        return r#"<div class="asset-shader-preview-empty">No map</div>"#.to_string();
    }
    format!(
        r#"<div class="asset-shader-preview"><img src="{path}"/></div>
<div class="asset-shader-preview-path">{path}</div>"#
    )
}
