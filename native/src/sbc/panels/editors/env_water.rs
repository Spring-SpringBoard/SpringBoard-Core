use spring_native::prelude::{Error, NativeInterfaceRef};

use crate::sbc::panels::editor::Editor;
use crate::sbc::panels::editor_base::{envelope, group_rml, resolve_base, section_rml, FieldSet};
use crate::sbc::panels::field::{ChangeQueue, FieldValue, InteractionQueue};
use crate::sbc::panels::fields::{BooleanField, ColorField, NumericField};
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
/// The texture fields (`normalTexture`, `foamTexture`, `texture`) are not
/// ported yet: they need the asset picker.
pub(crate) struct WaterEditor {
    fields: FieldSet,
}

fn num(name: &'static str, title: &'static str) -> Box<NumericField> {
    Box::new(NumericField::new(name, title, 0.0).decimals(2))
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
                num("repeatX", "Repeat X"),
                num("repeatY", "Repeat Y"),
            ]),
        }
    }

    fn water(&self, name: &str, value: &FieldValue, next: &mut u64) -> Vec<String> {
        let opts = match value {
            // The engine's water colours are RGB; the picker carries an alpha.
            FieldValue::Color(c) => serde_json::json!({ name: [c[0], c[1], c[2]] }),
            FieldValue::Number(n) => serde_json::json!({ name: n }),
            FieldValue::Bool(b) => serde_json::json!({ name: b }),
            FieldValue::Text(t) => serde_json::json!({ name: t }),
        };
        vec![envelope("SetWaterParamsCommand", next, opts)]
    }
}

impl Editor for WaterEditor {
    fn generate_rml(&self) -> String {
        let mut h = String::new();
        h.push_str(&group_rml(&[
            self.fields.rml("forceRendering"),
            self.fields.rml("numTiles"),
        ]));

        h.push_str(&section_rml("Water - perlin noise"));
        h.push_str(&group_rml(&[
            self.fields.rml("perlinStartFreq"),
            self.fields.rml("perlinLacunarity"),
        ]));
        h.push_str(&group_rml(&[self.fields.rml("perlinAmplitude")]));

        h.push_str(&section_rml("Water - diffuse"));
        h.push_str(&group_rml(&[
            self.fields.rml("diffuseFactor"),
            self.fields.rml("diffuseColor"),
        ]));

        h.push_str(&section_rml("Water - specular"));
        h.push_str(&group_rml(&[
            self.fields.rml("specularFactor"),
            self.fields.rml("specularPower"),
        ]));
        h.push_str(&group_rml(&[self.fields.rml("specularColor")]));
        h.push_str(&group_rml(&[self.fields.rml("ambientFactor")]));

        h.push_str(&section_rml("Water - fresnel"));
        h.push_str(&group_rml(&[
            self.fields.rml("fresnelMin"),
            self.fields.rml("fresnelMax"),
        ]));
        h.push_str(&group_rml(&[self.fields.rml("fresnelPower")]));
        h.push_str(&group_rml(&[self.fields.rml("reflectionDistortion")]));

        h.push_str(&section_rml("Water - blur"));
        h.push_str(&group_rml(&[
            self.fields.rml("blurBase"),
            self.fields.rml("blurExponent"),
        ]));

        h.push_str(&section_rml("Water - plane"));
        h.push_str(&group_rml(&[
            self.fields.rml("hasWaterPlane"),
            self.fields.rml("planeColor"),
        ]));

        h.push_str(&section_rml("Water - texture"));
        h.push_str(&group_rml(&[
            self.fields.rml("repeatX"),
            self.fields.rml("repeatY"),
        ]));
        h
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
        next: &mut u64,
    ) -> Vec<String> {
        let base = resolve_base(name).to_string();
        let value = self.fields.read(name, interface);
        self.water(&base, &value, next)
    }

    fn process_drag_end(&mut self, name: &str, next: &mut u64) -> Vec<String> {
        let base = resolve_base(name).to_string();
        let value = self.fields.value(name);
        self.water(&base, &value, next)
    }

    fn refresh_from_engine(&mut self, interface: &NativeInterfaceRef) {
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
        for name in ["forceRendering", "hasWaterPlane"] {
            if let Ok((_, _, bool_value, has_bool, _)) = gfx.get_water_rendering(name, "") {
                if has_bool {
                    self.fields.set(name, FieldValue::Bool(bool_value));
                }
            }
        }
    }

    fn drag_field(&mut self, name: &str, dx: f32, interface: &NativeInterfaceRef) -> bool {
        self.fields.drag(name, dx, interface)
    }

    fn drag_end_field(&mut self, name: &str, interface: &NativeInterfaceRef) -> bool {
        self.fields.drag_end(name, interface)
    }

    fn begin_edit_field(&mut self, name: &str, interface: &NativeInterfaceRef) {
        self.fields.begin_edit(name, interface)
    }

    fn cancel_edit_field(&mut self, name: &str, interface: &NativeInterfaceRef) {
        self.fields.cancel_edit(name, interface)
    }

    fn field_is_text_edit(&self, name: &str) -> bool {
        self.fields.is_text_edit(name)
    }

    fn field_color(&self, name: &str) -> Option<[f32; 4]> {
        self.fields.color(name)
    }

    fn set_field_color(&mut self, name: &str, rgba: [f32; 4], interface: &NativeInterfaceRef) {
        self.fields.set(name, FieldValue::Color(rgba));
        let _ = self.fields.write_values(interface);
    }
}
