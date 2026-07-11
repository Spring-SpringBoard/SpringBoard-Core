use spring_native::prelude::{Error, NativeInterfaceRef};

use crate::sbc::command_system::model::Models;
use crate::sbc::panels::editor::Editor;
use crate::sbc::panels::editor_base::{envelope, resolve_base, FieldSet, Layout};
use crate::sbc::panels::field::{ChangeQueue, Field, FieldValue, InteractionQueue};
use crate::sbc::panels::fields::{AssetField, BooleanField, NumericField};
use crate::sbc::panels::registry::{EditorSpec, Tab};
use crate::sbc::textures::TextureModel;

// Mirrors TerrainSettingsEditor:Register in scen_edit/view/map/terrain_settings_editor.lua.
inventory::submit! {
    EditorSpec {
        name: "terrainSettingsEditor",
        tab: Tab::Map,
        order: 99,
        caption: "Settings",
        tooltip: "Map settings",
        image: "LuaUI/images/scenedit/globe.png",
        make: || Box::new(MapSettingsEditor::new()),
    }
}

const BOOLEANS: &[&str] = &["voidWater", "voidGround", "splatDetailNormalDiffuseAlpha"];
const SPLAT_SCALE_FIELDS: &[&str] = &[
    "splatTexScale0",
    "splatTexScale1",
    "splatTexScale2",
    "splatTexScale3",
];
const SPLAT_MULT_FIELDS: &[&str] = &[
    "splatTexMult0",
    "splatTexMult1",
    "splatTexMult2",
    "splatTexMult3",
];
const SHADING_TOGGLES: &[(&str, &str, &str)] = &[
    ("tex_specular", "specular", "Specular"),
    ("tex_emission", "emission", "Emission"),
    ("tex_refl", "refl", "Reflection"),
    ("tex_splat_distr", "splat_distr", "Splat distribution"),
    ("tex_splat_normals0", "splat_normals0", "Splat normals 1"),
    ("tex_splat_normals1", "splat_normals1", "Splat normals 2"),
    ("tex_splat_normals2", "splat_normals2", "Splat normals 3"),
    ("tex_splat_normals3", "splat_normals3", "Splat normals 4"),
    ("tex_detail", "detail", "Detail"),
];

/// Map rendering flags and the detail texture. Every field is a key of
/// `SetMapRenderingParamsCommand`'s options except `detailTexture`, which the
/// engine takes through its own map-texture binding.
///
/// The command is not undoable (Lua's undo is a stub), so there is nothing to
/// preview: a change applies immediately and stays applied.
pub(crate) struct MapSettingsEditor {
    fields: FieldSet,
}

impl MapSettingsEditor {
    pub(crate) fn new() -> Self {
        let mut fields: Vec<Box<dyn Field>> = vec![
            Box::new(BooleanField::new("voidWater", "Void water", false)),
            Box::new(BooleanField::new("voidGround", "Void ground", false)),
            Box::new(BooleanField::new(
                "splatDetailNormalDiffuseAlpha",
                "DNTS diffuse alpha",
                false,
            )),
            Box::new(
                NumericField::new("splatTexScale0", "Scale 1", 1.0)
                    .min(0.0)
                    .max(1000.0),
            ),
            Box::new(
                NumericField::new("splatTexScale1", "Scale 2", 1.0)
                    .min(0.0)
                    .max(1000.0),
            ),
            Box::new(
                NumericField::new("splatTexScale2", "Scale 3", 1.0)
                    .min(0.0)
                    .max(1000.0),
            ),
            Box::new(
                NumericField::new("splatTexScale3", "Scale 4", 1.0)
                    .min(0.0)
                    .max(1000.0),
            ),
            Box::new(
                NumericField::new("splatTexMult0", "Mult 1", 1.0)
                    .min(0.0)
                    .max(1000.0),
            ),
            Box::new(
                NumericField::new("splatTexMult1", "Mult 2", 1.0)
                    .min(0.0)
                    .max(1000.0),
            ),
            Box::new(
                NumericField::new("splatTexMult2", "Mult 3", 1.0)
                    .min(0.0)
                    .max(1000.0),
            ),
            Box::new(
                NumericField::new("splatTexMult3", "Mult 4", 1.0)
                    .min(0.0)
                    .max(1000.0),
            ),
            Box::new(
                AssetField::new(
                    "detailTexture",
                    "Detail texture",
                    "springboard/assets/core/detail",
                )
                .extensions(&[".png", ".jpg", ".tga", ".dds", ".bmp"]),
            ),
        ];
        for (field, _, caption) in SHADING_TOGGLES {
            fields.push(Box::new(BooleanField::new(*field, *caption, false)));
        }
        MapSettingsEditor {
            fields: FieldSet::new(fields),
        }
    }

    fn rendering(&self, name: &str, value: &FieldValue, next: &mut u64) -> Vec<String> {
        if let Some((_, shading, _)) = SHADING_TOGGLES.iter().find(|(field, _, _)| *field == name) {
            return vec![envelope(
                "SetMapShadingTextureEnabledCommand",
                next,
                serde_json::json!({
                    "name": shading,
                    "value": matches!(value, FieldValue::Bool(true)),
                }),
            )];
        }
        let opts = if SPLAT_SCALE_FIELDS.contains(&name) {
            serde_json::json!({ "splatTexScales": self.splat_values(SPLAT_SCALE_FIELDS) })
        } else if SPLAT_MULT_FIELDS.contains(&name) {
            serde_json::json!({ "splatTexMults": self.splat_values(SPLAT_MULT_FIELDS) })
        } else {
            match value {
                FieldValue::Bool(b) => serde_json::json!({ name: b }),
                FieldValue::Text(t) => serde_json::json!({ name: t }),
                FieldValue::Number(n) => serde_json::json!({ name: n }),
                FieldValue::Color(c) => serde_json::json!({ name: c }),
            }
        };
        vec![envelope("SetMapRenderingParamsCommand", next, opts)]
    }

    fn splat_values(&self, fields: &[&str]) -> [f32; 4] {
        [
            self.fields.number(fields[0]),
            self.fields.number(fields[1]),
            self.fields.number(fields[2]),
            self.fields.number(fields[3]),
        ]
    }
}

impl Editor for MapSettingsEditor {
    fn generate_rml(&self) -> String {
        self.fields.generate_rml(&[
            Layout::Group(&["voidWater", "voidGround"]),
            Layout::Field("splatDetailNormalDiffuseAlpha"),
            Layout::Section("Splat mapping"),
            Layout::Group(SPLAT_SCALE_FIELDS),
            Layout::Group(SPLAT_MULT_FIELDS),
            Layout::Section("Map textures"),
            Layout::Field("detailTexture"),
            Layout::Group(&["tex_specular", "tex_emission"]),
            Layout::Group(&["tex_refl", "tex_splat_distr"]),
            Layout::Group(&["tex_splat_normals0", "tex_splat_normals1"]),
            Layout::Group(&["tex_splat_normals2", "tex_splat_normals3"]),
            Layout::Field("tex_detail"),
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
        next: &mut u64,
    ) -> Vec<String> {
        let base = resolve_base(name).to_string();
        let value = self.fields.read(name, interface);
        self.rendering(&base, &value, next)
    }

    fn process_drag_end(&mut self, name: &str, next: &mut u64) -> Vec<String> {
        let base = resolve_base(name).to_string();
        let value = self.fields.value(name);
        self.rendering(&base, &value, next)
    }

    fn refresh_from_engine(&mut self, interface: &NativeInterfaceRef, models: &mut Models) {
        let gfx = interface.gfx();
        for name in BOOLEANS {
            if let Ok((_, _, bool_value, has_bool, _)) = gfx.get_map_rendering(name, "") {
                if has_bool {
                    self.fields.set(name, FieldValue::Bool(bool_value));
                }
            }
        }
        if let Ok((values, ..)) = gfx.get_map_rendering("splatTexScales", "") {
            for (name, value) in SPLAT_SCALE_FIELDS.iter().zip(values) {
                self.fields.set(name, FieldValue::Number(value));
            }
        }
        if let Ok((values, ..)) = gfx.get_map_rendering("splatTexMults", "") {
            for (name, value) in SPLAT_MULT_FIELDS.iter().zip(values) {
                self.fields.set(name, FieldValue::Number(value));
            }
        }
        let textures = &models.get::<TextureModel>().shading;
        for (field, shading, _) in SHADING_TOGGLES {
            self.fields
                .set(field, FieldValue::Bool(textures.texture(shading).is_some()));
        }
    }

    crate::sb_field_editor_methods!();
}
