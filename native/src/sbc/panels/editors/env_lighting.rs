use spring_native::prelude::{Error, NativeInterfaceRef};

use crate::sbc::command_system::model::Models;
use crate::sbc::panels::editor::Editor;
use crate::sbc::panels::editor_base::{envelope, group_rml, resolve_base, section_rml, FieldSet};
use crate::sbc::panels::field::{ChangeQueue, FieldValue, InteractionQueue};
use crate::sbc::panels::fields::{ChoiceField, ColorField, NumericField};
use crate::sbc::panels::registry::{EditorSpec, Tab};

// Mirrors LightingEditor:Register in scen_edit/view/map/lighting_editor.lua.
inventory::submit! {
    EditorSpec {
        name: "lightingEditor",
        tab: Tab::Env,
        order: 0,
        caption: "Lighting",
        tooltip: "Edit lighting",
        image: "LuaUI/images/scenedit/sunbeams.png",
        make: || Box::new(LightingEditor::new()),
    }
}

/// Fields whose changes go through `SetSunLightingCommand`.
const SUN_LIGHTING_FIELDS: &[&str] = &[
    "groundDiffuseColor",
    "groundAmbientColor",
    "groundSpecularColor",
    "unitDiffuseColor",
    "unitAmbientColor",
    "unitSpecularColor",
    "groundShadowDensity",
    "modelShadowDensity",
];

const SUN_DIR_FIELDS: &[&str] = &["sunDirX", "sunDirY", "sunDirZ"];

/// Lighting — a port of `scen_edit/view/map/lighting_editor.lua`.
pub(crate) struct LightingEditor {
    fields: FieldSet,
}

impl LightingEditor {
    pub(crate) fn new() -> Self {
        let dir = |name: &'static str, title: &'static str| {
            Box::new(
                NumericField::new(name, title, 0.0)
                    .step(0.002)
                    .decimals(2)
                    .compact(),
            )
        };
        let density = |name: &'static str| {
            Box::new(
                NumericField::new(name, "Shadow density", 0.0)
                    .min(0.0)
                    .max(1.0)
                    .decimals(2),
            )
        };

        LightingEditor {
            fields: FieldSet::new(vec![
                Box::new(ChoiceField::new(
                    "shadowMode",
                    "Shadows",
                    vec!["Off".into(), "Terrain".into(), "Full".into()],
                )),
                dir("sunDirX", "Dir X"),
                dir("sunDirY", "Dir Y"),
                dir("sunDirZ", "Dir Z"),
                Box::new(ColorField::new("groundDiffuseColor", "Diffuse")),
                Box::new(ColorField::new("groundAmbientColor", "Ambient")),
                Box::new(ColorField::new("groundSpecularColor", "Specular")),
                density("groundShadowDensity"),
                Box::new(ColorField::new("unitDiffuseColor", "Diffuse")),
                Box::new(ColorField::new("unitAmbientColor", "Ambient")),
                Box::new(ColorField::new("unitSpecularColor", "Specular")),
                density("modelShadowDensity"),
            ]),
        }
    }

    /// Turn a committed field value into command envelopes. `shadowMode` is not
    /// a command: it is an engine console action, as in Lua.
    fn dispatch(
        &mut self,
        base: &str,
        value: &FieldValue,
        interface: &NativeInterfaceRef,
        next: &mut u64,
    ) -> Vec<String> {
        if base == "shadowMode" {
            if let FieldValue::Text(mode) = value {
                let arg = match mode.as_str() {
                    "Off" => "0",
                    "Terrain" => "2",
                    _ => "1",
                };
                let _ = interface.messages().send_commands("shadows", arg);
            }
            return vec![];
        }

        if SUN_DIR_FIELDS.contains(&base) {
            return vec![envelope(
                "SetSunParametersCommand",
                next,
                serde_json::json!({
                    "dirX": self.fields.number("sunDirX"),
                    "dirY": self.fields.number("sunDirY"),
                    "dirZ": self.fields.number("sunDirZ"),
                }),
            )];
        }

        if SUN_LIGHTING_FIELDS.contains(&base) {
            let opts = match value {
                FieldValue::Color(c) => serde_json::json!({ base: c }),
                FieldValue::Number(n) => serde_json::json!({ base: n }),
                _ => return vec![],
            };
            return vec![envelope("SetSunLightingCommand", next, opts)];
        }

        vec![]
    }
}

impl Editor for LightingEditor {
    fn generate_rml(&self) -> String {
        let mut h = String::new();
        h.push_str(&section_rml("Shadows"));
        h.push_str(&self.fields.rml("shadowMode"));

        h.push_str(&group_rml(&[
            self.fields.rml("sunDirX"),
            self.fields.rml("sunDirY"),
            self.fields.rml("sunDirZ"),
        ]));

        h.push_str(&section_rml("Sun ground color"));
        h.push_str(&group_rml(&[
            self.fields.rml("groundDiffuseColor"),
            self.fields.rml("groundAmbientColor"),
        ]));
        h.push_str(&group_rml(&[self.fields.rml("groundSpecularColor")]));
        h.push_str(&self.fields.rml("groundShadowDensity"));

        h.push_str(&section_rml("Sun unit color"));
        h.push_str(&group_rml(&[
            self.fields.rml("unitDiffuseColor"),
            self.fields.rml("unitAmbientColor"),
        ]));
        h.push_str(&group_rml(&[self.fields.rml("unitSpecularColor")]));
        h.push_str(&self.fields.rml("modelShadowDensity"));
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

        // A colour sub-field commits only that channel.
        if base != name {
            let sub = name.rsplit_once('-').unwrap().1.to_string();
            if let Some(value) = self
                .fields
                .get_mut(&base)
                .and_then(|f| f.read_sub_field(&sub, interface))
            {
                return self.dispatch(&base, &value, interface, next);
            }
        }

        let value = self.fields.read(name, interface);
        self.dispatch(&base, &value, interface, next)
    }

    fn process_drag_end(&mut self, name: &str, next: &mut u64) -> Vec<String> {
        // The drag already updated the value; do not consult the DOM.
        let base = resolve_base(name).to_string();
        let value = self.fields.value(name);

        if SUN_LIGHTING_FIELDS.contains(&base.as_str()) {
            let opts = match &value {
                FieldValue::Color(c) => serde_json::json!({ base: c }),
                FieldValue::Number(n) => serde_json::json!({ base: n }),
                _ => return vec![],
            };
            return vec![envelope("SetSunLightingCommand", next, opts)];
        }
        if SUN_DIR_FIELDS.contains(&base.as_str()) {
            return vec![envelope(
                "SetSunParametersCommand",
                next,
                serde_json::json!({
                    "dirX": self.fields.number("sunDirX"),
                    "dirY": self.fields.number("sunDirY"),
                    "dirZ": self.fields.number("sunDirZ"),
                }),
            )];
        }
        vec![]
    }

    fn refresh_from_engine(&mut self, interface: &NativeInterfaceRef, _models: &mut Models) {
        let gfx = interface.gfx();

        if let Ok((v, ..)) = gfx.get_sun("dir", "") {
            self.fields.set("sunDirX", FieldValue::Number(v[0]));
            self.fields.set("sunDirY", FieldValue::Number(v[1]));
            self.fields.set("sunDirZ", FieldValue::Number(v[2]));
        }

        for (key, mode, ground, unit) in [
            ("diffuse", "unit", "groundDiffuseColor", "unitDiffuseColor"),
            ("ambient", "unit", "groundAmbientColor", "unitAmbientColor"),
            (
                "specular",
                "unit",
                "groundSpecularColor",
                "unitSpecularColor",
            ),
        ] {
            if let Ok((v, ..)) = gfx.get_sun(key, "") {
                self.fields.set(ground, FieldValue::Color(v));
            }
            if let Ok((v, ..)) = gfx.get_sun(key, mode) {
                self.fields.set(unit, FieldValue::Color(v));
            }
        }

        if let Ok((v, ..)) = gfx.get_sun("shadowDensity", "") {
            self.fields
                .set("groundShadowDensity", FieldValue::Number(v[0]));
        }
        if let Ok((v, ..)) = gfx.get_sun("shadowDensity", "unit") {
            self.fields
                .set("modelShadowDensity", FieldValue::Number(v[0]));
        }

        if let Ok((mode, _)) = interface.config().get_config_int("Shadows", None) {
            let label = match mode {
                0 => "Off",
                2 => "Terrain",
                _ => "Full",
            };
            self.fields
                .set("shadowMode", FieldValue::Text(label.to_string()));
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

    fn field_color(&self, name: &str) -> Option<[f32; 4]> {
        self.fields.color(name)
    }

    fn set_field_color(&mut self, name: &str, rgba: [f32; 4], interface: &NativeInterfaceRef) {
        self.fields.set(name, FieldValue::Color(rgba));
        let _ = self.fields.write_values(interface);
    }

    fn field_asset(&self, name: &str) -> Option<(String, Vec<String>)> {
        self.fields.asset_info(name)
    }

    fn set_field_text(&mut self, name: &str, value: &str, interface: &NativeInterfaceRef) {
        self.fields.set(name, FieldValue::Text(value.to_string()));
        let _ = self.fields.write_values(interface);
    }
}
