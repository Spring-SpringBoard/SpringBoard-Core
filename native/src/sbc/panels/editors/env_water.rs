use spring_native::prelude::{Error, NativeInterfaceRef};

use crate::sbc::command_system::command::Command;
use crate::sbc::command_system::model::Models;
use crate::sbc::map_settings::commands::SetWaterParamsCommand;
use crate::sbc::panels::editor::Editor;
use crate::sbc::panels::editor_base::{resolve_base, FieldSet, Layout};
use crate::sbc::panels::field::{ChangeQueue, FieldValue, InteractionQueue};
use crate::sbc::panels::fields::{AssetField, BooleanField, ColorField, NumericField};
use crate::sbc::panels::registry::{EditorSpec, Tab};

// Mirrors WaterEditor:Register in scen_edit/view/map/water_editor.lua.
inventory::submit! {
    EditorSpec {
        name: "waterEditor",
        tab: Tab::Env,
        order: 2,
        caption: "Water",
        tooltip: "Edit water",
        image: "LuaUI/images/scenedit/wave-crest.png",
        make: || Box::new(WaterEditor::new()),
    }
}

/// Every field here is a key of `SetWaterParamsCommand`'s options, so the
/// dispatch is uniform: send the one field that changed.
///
/// Texture fields pick a path from the VFS with the asset picker; the command
/// applies them through the engine's dedicated water-texture binding.
pub(crate) struct WaterEditor {
    fields: FieldSet,
}

fn num(name: &'static str, title: &'static str) -> Box<NumericField> {
    Box::new(NumericField::new(name, title, 0.0).decimals(2))
}

/// Water textures live under `bitmaps/`, as in `water_editor.lua`.
fn tex(name: &'static str, title: &'static str) -> Box<AssetField> {
    Box::new(
        AssetField::new(name, title, "bitmaps")
            .extensions(&[".png", ".jpg", ".tga", ".dds", ".bmp"]),
    )
}

impl WaterEditor {
    pub(crate) fn new() -> Self {
        WaterEditor {
            fields: FieldSet::new(vec![
                Box::new(BooleanField::new(
                    "forceRendering",
                    "Forced rendering",
                    false,
                )),
                num("numTiles", "NumTiles"),
                num("perlinStartFreq", "Start freq"),
                num("perlinLacunarity", "Lacunarity"),
                num("perlinAmplitude", "Amplitude"),
                num("diffuseFactor", "Factor"),
                Box::new(ColorField::new("diffuseColor", "Diffuse color")),
                num("specularFactor", "Factor"),
                num("specularPower", "Power"),
                Box::new(ColorField::new("specularColor", "Color")),
                num("ambientFactor", "Ambient factor"),
                num("fresnelMin", "Min"),
                num("fresnelMax", "Max"),
                num("fresnelPower", "Power"),
                num("reflectionDistortion", "Reflection distortion"),
                num("blurBase", "Base"),
                num("blurExponent", "Exponent"),
                Box::new(BooleanField::new("hasWaterPlane", "Enabled", false)),
                Box::new(ColorField::new("planeColor", "Color")),
                Box::new(BooleanField::new("shoreWaves", "Enabled", false)),
                num("repeatX", "Repeat X"),
                num("repeatY", "Repeat Y"),
                tex("normalTexture", "Normal texture"),
                tex("foamTexture", "Foam texture"),
                tex("texture", "Texture"),
            ]),
        }
    }

    fn water(&self, name: &str, value: &FieldValue) -> Vec<Box<dyn Command>> {
        let opts = match value {
            // The engine's water colours are RGB; the picker carries an alpha.
            FieldValue::Color(c) => serde_json::json!({ name: [c[0], c[1], c[2]] }),
            FieldValue::Number(n) => serde_json::json!({ name: n }),
            FieldValue::Bool(b) => serde_json::json!({ name: b }),
            FieldValue::Text(t) => serde_json::json!({ name: t }),
        };
        match SetWaterParamsCommand::from_opts(opts) {
            Some(c) => vec![Box::new(c)],
            None => vec![],
        }
    }
}

impl Editor for WaterEditor {
    fn generate_rml(&self) -> String {
        self.fields.generate_rml(&[
            Layout::Group(&["forceRendering", "numTiles"]),
            Layout::Field("normalTexture"),
            Layout::Section("Water - perlin noise"),
            Layout::Group(&["perlinStartFreq", "perlinLacunarity"]),
            Layout::Group(&["perlinAmplitude"]),
            Layout::Section("Water - diffuse"),
            Layout::Group(&["diffuseFactor", "diffuseColor"]),
            Layout::Section("Water - specular"),
            Layout::Group(&["specularFactor", "specularPower"]),
            Layout::Group(&["specularColor"]),
            Layout::Group(&["ambientFactor"]),
            Layout::Section("Water - fresnel"),
            Layout::Group(&["fresnelMin", "fresnelMax"]),
            Layout::Group(&["fresnelPower"]),
            Layout::Group(&["reflectionDistortion"]),
            Layout::Section("Water - blur"),
            Layout::Group(&["blurBase", "blurExponent"]),
            Layout::Section("Water - plane"),
            Layout::Group(&["hasWaterPlane", "planeColor"]),
            Layout::Section("Water - waves"),
            Layout::Group(&["shoreWaves", "foamTexture"]),
            Layout::Section("Water - texture"),
            Layout::Field("texture"),
            Layout::Group(&["repeatX", "repeatY"]),
        ])
    }

    fn bind_fields(
        &mut self,
        interface: &NativeInterfaceRef,
        document: u64,
        changes: &ChangeQueue,
        interactions: &InteractionQueue,
    ) -> Result<(), Error> {
        self.fields.bind(interface, document, changes, interactions)
    }

    fn write_field_values(&self, interface: &NativeInterfaceRef) -> Result<(), Error> {
        self.fields.write_values(interface)
    }

    fn process_change(
        &mut self,
        name: &str,
        interface: &NativeInterfaceRef,
    ) -> Vec<Box<dyn Command>> {
        let base = resolve_base(name).to_string();
        let value = self.fields.read(name, interface);
        self.water(&base, &value)
    }

    fn process_drag_end(&mut self, name: &str) -> Vec<Box<dyn Command>> {
        let base = resolve_base(name).to_string();
        let value = self.fields.value(name);
        self.water(&base, &value)
    }

    fn refresh_from_engine(&mut self, interface: &NativeInterfaceRef, _models: &mut Models) {
        let gfx = interface.gfx();

        for name in [
            "numTiles",
            "perlinStartFreq",
            "perlinLacunarity",
            "perlinAmplitude",
            "diffuseFactor",
            "specularFactor",
            "specularPower",
            "ambientFactor",
            "fresnelMin",
            "fresnelMax",
            "fresnelPower",
            "reflectionDistortion",
            "blurBase",
            "blurExponent",
            "repeatX",
            "repeatY",
        ] {
            if let Ok((v, ..)) = gfx.get_water_rendering(name, "") {
                self.fields.set(name, FieldValue::Number(v[0]));
            }
        }

        for name in ["diffuseColor", "specularColor", "planeColor"] {
            if let Ok((v, ..)) = gfx.get_water_rendering(name, "") {
                self.fields.set(name, FieldValue::Color(v));
            }
        }

        // Boolean water params come back in the result's `boolValue`, flagged by
        // `hasBool` -- not in the float array, which stays zero for them.
        for name in ["forceRendering", "hasWaterPlane", "shoreWaves"] {
            if let Ok((_, _, bool_value, has_bool, _)) = gfx.get_water_rendering(name, "") {
                if has_bool {
                    self.fields.set(name, FieldValue::Bool(bool_value));
                }
            }
        }
    }

    crate::sb_field_editor_methods!();
}
