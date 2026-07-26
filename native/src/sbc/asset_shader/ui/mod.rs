mod behavior;
mod layout;
mod model;

use crate::sbc::panels::registry::{EditorSpec, Tab};
use crate::sbc::panels::runtime::Runtime;

use behavior::AssetShaderBehavior;
use model::asset_shader_model;

inventory::submit! {
    EditorSpec {
        name: "assetShaderEditor",
        tab: Tab::Objects,
        order: 50,
        caption: "Asset shader",
        tooltip: "Inspect and tune the generated-asset shader",
        image: "LuaUI/images/scenedit/sunbeams.png",
        make: || Box::new(Runtime::new(AssetShaderBehavior::default(), asset_shader_model())),
    }
}
