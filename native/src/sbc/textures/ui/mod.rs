mod behavior;
mod layout;
pub(crate) mod model;

use crate::sbc::panels::registry::{EditorSpec, Tab};
use crate::sbc::panels::runtime::Runtime;

use behavior::TextureBehavior;
use model::TextureUiModel;

// Mirrors TextureEditor:Register in scen_edit/view/map/texture_editor.lua.
inventory::submit! {
    EditorSpec {
        name: "textureEditor",
        tab: Tab::Map,
        order: 2,
        caption: "Texture",
        tooltip: "Edit textures",
        image: "LuaUI/images/scenedit/palette.png",
        make: || Box::new(Runtime::new(TextureBehavior, TextureUiModel::new())),
    }
}
