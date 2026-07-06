use serde::Deserialize;

/// Inputs for one `mapcompile` run: the exported image paths and height bounds.
#[derive(Clone, Deserialize, Debug)]
pub(crate) struct CompileMapOpts {
    #[serde(rename = "heightPath")]
    pub height_path: String,
    #[serde(rename = "diffusePath")]
    pub diffuse_path: String,
    #[serde(default, rename = "metalPath")]
    pub metal_path: Option<String>,
    #[serde(default, rename = "typePath")]
    pub type_path: Option<String>,
    #[serde(rename = "outputPath")]
    pub output_path: String,
    #[serde(default, rename = "writePath")]
    pub write_path: String,
    #[serde(default)]
    pub minimap: Option<String>,
    #[serde(default)]
    pub maxh: Option<String>,
    #[serde(default)]
    pub minh: Option<String>,
}
