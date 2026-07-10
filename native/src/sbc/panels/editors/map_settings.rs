use spring_native::prelude::{Error, NativeInterfaceRef};

use crate::sbc::command_system::model::Models;
use crate::sbc::panels::editor::Editor;
use crate::sbc::panels::editor_base::{envelope, group_rml, resolve_base, section_rml, FieldSet};
use crate::sbc::panels::field::{ChangeQueue, FieldValue, InteractionQueue};
use crate::sbc::panels::fields::{AssetField, BooleanField};
use crate::sbc::panels::registry::{EditorSpec, Tab};

// Mirrors TerrainSettingsEditor:Register in scen_edit/view/map/terrain_settings_editor.lua.
inventory::submit! {
    EditorSpec {
        name: "terrainSettingsEditor",
        tab: Tab::Map,
        order: 0,
        caption: "Settings",
        tooltip: "Map settings",
        image: "LuaUI/images/scenedit/globe.png",
        make: || Box::new(MapSettingsEditor::new()),
    }
}

const BOOLEANS: &[&str] = &["voidWater", "voidGround", "splatDetailNormalDiffuseAlpha"];

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
        MapSettingsEditor {
            fields: FieldSet::new(vec![
                Box::new(BooleanField::new("voidWater", "Void water", false)),
                Box::new(BooleanField::new("voidGround", "Void ground", false)),
                Box::new(BooleanField::new(
                    "splatDetailNormalDiffuseAlpha",
                    "DNTS diffuse alpha",
                    false,
                )),
                Box::new(
                    AssetField::new(
                        "detailTexture",
                        "Detail texture",
                        "springboard/assets/core/detail",
                    )
                    .extensions(&[".png", ".jpg", ".tga", ".dds", ".bmp"]),
                ),
            ]),
        }
    }

    fn rendering(&self, name: &str, value: &FieldValue, next: &mut u64) -> Vec<String> {
        let opts = match value {
            FieldValue::Bool(b) => serde_json::json!({ name: b }),
            FieldValue::Text(t) => serde_json::json!({ name: t }),
            FieldValue::Number(n) => serde_json::json!({ name: n }),
            FieldValue::Color(c) => serde_json::json!({ name: c }),
        };
        vec![envelope("SetMapRenderingParamsCommand", next, opts)]
    }
}

impl Editor for MapSettingsEditor {
    fn generate_rml(&self) -> String {
        let mut h = String::new();
        h.push_str(&group_rml(&[
            self.fields.rml("voidWater"),
            self.fields.rml("voidGround"),
        ]));
        h.push_str(&self.fields.rml("splatDetailNormalDiffuseAlpha"));
        h.push_str(&section_rml("Map textures"));
        h.push_str(&self.fields.rml("detailTexture"));
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
        self.rendering(&base, &value, next)
    }

    fn process_drag_end(&mut self, name: &str, next: &mut u64) -> Vec<String> {
        let base = resolve_base(name).to_string();
        let value = self.fields.value(name);
        self.rendering(&base, &value, next)
    }

    fn refresh_from_engine(&mut self, interface: &NativeInterfaceRef, _models: &mut Models) {
        let gfx = interface.gfx();
        for name in BOOLEANS {
            if let Ok((_, _, bool_value, has_bool, _)) = gfx.get_map_rendering(name, "") {
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
