use spring_native::prelude::{Error, NativeInterfaceRef};

use crate::sbc::command_system::model::Models;
use crate::sbc::panels::editor::Editor;
use crate::sbc::panels::editor_base::{envelope, group_rml, resolve_base, section_rml, FieldSet};
use crate::sbc::panels::field::{ChangeQueue, FieldValue, InteractionQueue};
use crate::sbc::panels::fields::{AssetField, ColorField, NumericField};
use crate::sbc::panels::registry::{EditorSpec, Tab};

// Mirrors SkyEditor:Register in scen_edit/view/map/sky_editor.lua.
inventory::submit! {
    EditorSpec {
        name: "skyEditor",
        tab: Tab::Env,
        order: 1,
        caption: "Sky",
        tooltip: "Edit sky and fog",
        image: "LuaUI/images/scenedit/night-sky.png",
        make: || Box::new(SkyEditor::new()),
    }
}

/// Sky and fog. Every atmosphere field goes through one command class; the
/// skybox is a texture path applied by its own engine call, as in Lua.
const ATMOSPHERE_FIELDS: &[&str] = &[
    "sunColor",
    "skyColor",
    "cloudColor",
    "fogColor",
    "fogStart",
    "fogEnd",
];

pub(crate) struct SkyEditor {
    fields: FieldSet,
}

impl SkyEditor {
    pub(crate) fn new() -> Self {
        SkyEditor {
            fields: FieldSet::new(vec![
                Box::new(ColorField::new("sunColor", "Sun")),
                Box::new(ColorField::new("skyColor", "Sky")),
                Box::new(ColorField::new("cloudColor", "Cloud")),
                Box::new(ColorField::new("fogColor", "Color")),
                Box::new(
                    NumericField::new("fogStart", "Start", 0.0)
                        .min(0.0)
                        .max(1.0)
                        .decimals(2),
                ),
                Box::new(
                    NumericField::new("fogEnd", "End", 0.0)
                        .min(0.0)
                        .max(1.0)
                        .decimals(2),
                ),
                Box::new(
                    AssetField::new("skyboxTexture", "Skybox", "skyboxes")
                        .extensions(&[".dds", ".png", ".jpg", ".tga"]),
                ),
            ]),
        }
    }

    fn atmosphere(&self, name: &str, value: &FieldValue, next: &mut u64) -> Vec<String> {
        let opts = match value {
            FieldValue::Color(c) => serde_json::json!({ name: c }),
            FieldValue::Number(n) => serde_json::json!({ name: n }),
            _ => return vec![],
        };
        vec![envelope("SetAtmosphereCommand", next, opts)]
    }
}

impl Editor for SkyEditor {
    fn generate_rml(&self) -> String {
        let mut h = String::new();
        h.push_str(&group_rml(&[
            self.fields.rml("sunColor"),
            self.fields.rml("skyColor"),
            self.fields.rml("cloudColor"),
        ]));
        h.push_str(&self.fields.rml("skyboxTexture"));
        h.push_str(&section_rml("Fog"));
        h.push_str(&group_rml(&[
            self.fields.rml("fogColor"),
            self.fields.rml("fogStart"),
            self.fields.rml("fogEnd"),
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
        if ATMOSPHERE_FIELDS.contains(&base.as_str()) {
            return self.atmosphere(&base, &value, next);
        }
        vec![]
    }

    fn process_drag_end(&mut self, name: &str, next: &mut u64) -> Vec<String> {
        let base = resolve_base(name).to_string();
        let value = self.fields.value(name);
        if ATMOSPHERE_FIELDS.contains(&base.as_str()) {
            return self.atmosphere(&base, &value, next);
        }
        vec![]
    }

    fn refresh_from_engine(&mut self, interface: &NativeInterfaceRef, _models: &mut Models) {
        let gfx = interface.gfx();
        for name in ["sunColor", "skyColor", "cloudColor", "fogColor"] {
            if let Ok((v, ..)) = gfx.get_atmosphere(name, "") {
                self.fields.set(name, FieldValue::Color(v));
            }
        }
        for name in ["fogStart", "fogEnd"] {
            if let Ok((v, ..)) = gfx.get_atmosphere(name, "") {
                self.fields.set(name, FieldValue::Number(v[0]));
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

    fn field_value(&self, name: &str) -> FieldValue {
        self.fields.value(name)
    }

    fn set_field_value(&mut self, name: &str, value: FieldValue, interface: &NativeInterfaceRef) {
        self.fields.set(resolve_base(name), value);
        let _ = self.fields.write_values(interface);
    }

    fn field_asset(&self, name: &str) -> Option<(String, Vec<String>)> {
        self.fields.asset_info(name)
    }
}
