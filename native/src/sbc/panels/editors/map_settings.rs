use spring_native::prelude::{Error, NativeInterfaceRef};

use std::cell::RefCell;
use std::collections::BTreeMap;
use std::rc::Rc;

use crate::sbc::command_system::command::Command;
use crate::sbc::command_system::model::Models;
use crate::sbc::map_settings::commands::{
    SetMapRenderingParamsCommand, SetMapShadingTextureEnabledCommand,
};
use crate::sbc::panels::editor::Editor;
use crate::sbc::panels::editor_base::{resolve_base, FieldSet, Layout};
use crate::sbc::panels::field::{ChangeQueue, Field, FieldValue, InteractionQueue};
use crate::sbc::panels::fields::{AssetField, BooleanField, NumericField};
use crate::sbc::panels::grid::{list_assets, GridItem, GridView};
use crate::sbc::panels::registry::{EditorSpec, Tab};
use crate::sbc::rml::{element_by_id, escape_rml};
use crate::sbc::textures::commands::{CreateShadingTextureCommand, ImportShadingImageCommand};
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
const SPLAT_SCALE_ROW_ONE: &[&str] = &["splatTexScale0", "splatTexScale1"];
const SPLAT_SCALE_ROW_TWO: &[&str] = &["splatTexScale2", "splatTexScale3"];
const SPLAT_MULT_FIELDS: &[&str] = &[
    "splatTexMult0",
    "splatTexMult1",
    "splatTexMult2",
    "splatTexMult3",
];
const SPLAT_MULT_ROW_ONE: &[&str] = &["splatTexMult0", "splatTexMult1"];
const SPLAT_MULT_ROW_TWO: &[&str] = &["splatTexMult2", "splatTexMult3"];
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

#[derive(Debug, Clone)]
enum ShadingEvent {
    Open(String),
    ShowNew,
    New,
    Existing,
    Disable,
    Cancel,
}

#[derive(Clone, Copy, PartialEq, Eq)]
enum ShadingSource {
    New,
    Existing,
}

/// Map rendering flags and the detail texture. Every field is a key of
/// `SetMapRenderingParamsCommand`'s options except `detailTexture`, which the
/// engine takes through its own map-texture binding.
///
/// The command is not undoable (Lua's undo is a stub), so there is nothing to
/// preview: a change applies immediately and stays applied.
pub(crate) struct MapSettingsEditor {
    fields: FieldSet,
    shading_grid: GridView,
    shading_events: Rc<RefCell<Vec<ShadingEvent>>>,
    shading_enabled: BTreeMap<String, bool>,
    dialog: Option<String>,
    shading_source: Option<ShadingSource>,
    document: Option<u64>,
}

impl MapSettingsEditor {
    pub(crate) fn new() -> Self {
        let fields: Vec<Box<dyn Field>> = vec![
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
                // A root *inside* an asset pack, not a VFS path: the picker walks
                // the packs and lists `assets/<pack>/detail/`.
                AssetField::new("detailTexture", "Detail texture", "detail/")
                    .extensions(&["png", "jpg", "tga", "dds", "bmp"]),
            ),
        ];
        MapSettingsEditor {
            fields: FieldSet::new(fields),
            shading_grid: GridView::new("map-shading-texture-grid", 64),
            shading_events: Rc::new(RefCell::new(Vec::new())),
            shading_enabled: BTreeMap::new(),
            dialog: None,
            shading_source: None,
            document: None,
        }
    }

    fn shading_markup(&self) -> String {
        let mut html = String::new();
        for (field, _, caption) in SHADING_TOGGLES {
            html.push_str(&format!(
                r#"<div class="field-row"><button id="shading-{field}" class="field-composite-button shading-texture-button"><span>{caption}</span><span id="shading-status-{field}"></span></button></div>"#,
                field = escape_rml(field),
                caption = escape_rml(caption),
            ));
        }
        html
    }

    fn dialog_markup(&self) -> String {
        format!(
            r#"<div id="shading-texture-dialog" class="picker-backdrop hidden">
                <div class="dialog picker-dialog asset-dialog">
                    <div class="dialog-header"><span id="shading-dialog-title" class="dialog-title">Map texture</span></div>
                    <div class="dialog-content">
                        <div id="shading-source-choice" class="shading-dialog-actions">
                            <button id="shading-new" class="dialog-button primary">New texture</button>
                            <button id="shading-existing" class="dialog-button">Choose existing</button>
                            <button id="shading-disable" class="dialog-button">Disable</button>
                        </div>
                        <div id="shading-new-form" class="hidden">
                            <div class="field-row"><label class="field-label">Width:</label><input id="shading-width" class="field-input" value="1024"/></div>
                            <div class="field-row"><label class="field-label">Height:</label><input id="shading-height" class="field-input" value="1024"/></div>
                            <div class="dialog-hint">Creates a blank texture using this channel's sensible default colour.</div>
                            <button id="shading-create" class="dialog-button primary">Create texture</button>
                        </div>
                        <div id="shading-existing-grid" class="hidden">{}</div>
                    </div>
                    <div class="dialog-footer"><button id="shading-cancel" class="dialog-button">Cancel</button></div>
                </div>
            </div>"#,
            self.shading_grid.container_rml()
        )
    }

    fn render_shading_fields(&self, interface: &NativeInterfaceRef, document: u64) {
        for (field, _, caption) in SHADING_TOGGLES {
            let Some(button) = element_by_id(interface, document, &format!("shading-{field}"))
            else {
                continue;
            };
            let enabled = self.shading_enabled.get(*field).copied().unwrap_or(false);
            let status = if enabled {
                "<span class=\"shading-enabled\">enabled</span>"
            } else {
                "<span class=\"shading-disabled\">not set</span>"
            };
            let markup = format!(
                "<span>{}</span><span id=\"shading-status-{}\">{}</span>",
                escape_rml(caption),
                escape_rml(field),
                status,
            );
            let _ = interface.rml_ui().element_set_inner_rml(button, &markup);
        }
    }

    fn render_dialog(&self, interface: &NativeInterfaceRef, document: u64) {
        let Some(dialog) = element_by_id(interface, document, "shading-texture-dialog") else {
            return;
        };
        let open = self.dialog.is_some();
        let _ = interface
            .rml_ui()
            .element_set_class(dialog, "hidden", !open);
        if let Some(name) = &self.dialog {
            if let Some(title) = element_by_id(interface, document, "shading-dialog-title") {
                let caption = SHADING_TOGGLES
                    .iter()
                    .find(|(_, shading, _)| shading == name)
                    .map(|(_, _, caption)| *caption)
                    .unwrap_or(name.as_str());
                let _ = interface
                    .rml_ui()
                    .element_set_inner_rml(title, &format!("{} texture", escape_rml(caption)));
            }
        }
        if let Some(choice) = element_by_id(interface, document, "shading-source-choice") {
            let _ = interface.rml_ui().element_set_class(
                choice,
                "hidden",
                !open || self.shading_source.is_some(),
            );
        }
        if let Some(new_form) = element_by_id(interface, document, "shading-new-form") {
            let _ = interface.rml_ui().element_set_class(
                new_form,
                "hidden",
                !open || self.shading_source != Some(ShadingSource::New),
            );
        }
        if let Some(existing) = element_by_id(interface, document, "shading-existing-grid") {
            let _ = interface.rml_ui().element_set_class(
                existing,
                "hidden",
                !open || self.shading_source != Some(ShadingSource::Existing),
            );
        }
    }

    fn render_existing_grid(
        &mut self,
        interface: &NativeInterfaceRef,
        document: u64,
    ) -> Result<(), Error> {
        let items = list_assets(
            interface,
            "springboard/assets/core/detail",
            &[".png", ".jpg", ".tga", ".dds", ".bmp"],
        )
        .into_iter()
        .map(|mut item| {
            item.tooltip = Some("Choose this existing texture".to_string());
            item
        })
        .collect::<Vec<GridItem>>();
        self.shading_grid.set_items(items);
        self.shading_grid.render(interface, document)
    }

    fn rendering(&self, name: &str, value: &FieldValue) -> Vec<Box<dyn Command>> {
        if let Some((_, shading, _)) = SHADING_TOGGLES.iter().find(|(field, _, _)| *field == name) {
            return vec![Box::new(SetMapShadingTextureEnabledCommand::new(
                *shading,
                matches!(value, FieldValue::Bool(true)),
            ))];
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
        match SetMapRenderingParamsCommand::from_opts(opts) {
            Some(c) => vec![Box::new(c)],
            None => vec![],
        }
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
    fn has_open_modal(&self) -> bool {
        self.dialog.is_some()
    }

    fn generate_rml(&self) -> String {
        self.fields.generate_rml(&[
            Layout::Section("Map textures"),
            Layout::Field("detailTexture"),
            Layout::Raw(self.shading_markup()),
            Layout::Section("Terrain visibility"),
            // A switch button needs room for its label, track and clear state;
            // stack these rather than squeezing two into checkbox-sized cells.
            Layout::Field("voidWater"),
            Layout::Field("voidGround"),
            Layout::Field("splatDetailNormalDiffuseAlpha"),
            Layout::Section("Splat mapping"),
            // Four label/value controls across 500dp leave the values clipped.
            // Two even columns retain a comfortable numeric editing target.
            Layout::Group(SPLAT_SCALE_ROW_ONE),
            Layout::Group(SPLAT_SCALE_ROW_TWO),
            Layout::Group(SPLAT_MULT_ROW_ONE),
            Layout::Group(SPLAT_MULT_ROW_TWO),
        ])
    }

    fn bind_fields(
        &mut self,
        interface: &NativeInterfaceRef,
        document: u64,
        changes: &ChangeQueue,
        interactions: &InteractionQueue,
    ) -> Result<(), Error> {
        self.document = Some(document);
        self.fields
            .bind(interface, document, changes, interactions)?;
        if let Some(host) = element_by_id(interface, document, "map-shading-modal") {
            interface
                .rml_ui()
                .element_set_inner_rml(host, &self.dialog_markup())?;
        }
        for (field, shading, _) in SHADING_TOGGLES {
            let Some(button) = element_by_id(interface, document, &format!("shading-{field}"))
            else {
                continue;
            };
            let events = self.shading_events.clone();
            let name = (*shading).to_string();
            interface
                .rml_ui()
                .element_add_event_listener(button, "click", false, move || {
                    events.borrow_mut().push(ShadingEvent::Open(name.clone()));
                })?;
        }
        for (id, event) in [
            ("shading-new", ShadingEvent::ShowNew),
            ("shading-existing", ShadingEvent::Existing),
            ("shading-create", ShadingEvent::New),
            ("shading-disable", ShadingEvent::Disable),
            ("shading-cancel", ShadingEvent::Cancel),
        ] {
            let Some(button) = element_by_id(interface, document, id) else {
                continue;
            };
            let events = self.shading_events.clone();
            interface
                .rml_ui()
                .element_add_event_listener(button, "click", false, move || {
                    events.borrow_mut().push(event.clone());
                })?;
        }
        self.render_existing_grid(interface, document)?;
        self.render_shading_fields(interface, document);
        self.render_dialog(interface, document);
        Ok(())
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
        self.rendering(&base, &value)
    }

    fn process_drag_end(&mut self, name: &str) -> Vec<Box<dyn Command>> {
        let base = resolve_base(name).to_string();
        let value = self.fields.value(name);
        self.rendering(&base, &value)
    }

    fn tick(&mut self, interface: &NativeInterfaceRef, document: u64) -> Vec<Box<dyn Command>> {
        let mut commands: Vec<Box<dyn Command>> = Vec::new();
        for event in self.shading_events.borrow_mut().drain(..) {
            match event {
                ShadingEvent::Open(name) => {
                    self.dialog = Some(name);
                    self.shading_source = None;
                }
                ShadingEvent::ShowNew => self.shading_source = Some(ShadingSource::New),
                ShadingEvent::Existing => self.shading_source = Some(ShadingSource::Existing),
                ShadingEvent::Cancel => {
                    self.dialog = None;
                    self.shading_source = None;
                }
                ShadingEvent::New | ShadingEvent::Disable => {
                    if let Some(name) = self.dialog.take() {
                        let enabled = matches!(event, ShadingEvent::New);
                        let Some((field, _, _)) = SHADING_TOGGLES
                            .iter()
                            .find(|(_, shading, _)| *shading == name)
                        else {
                            continue;
                        };
                        self.shading_enabled.insert((*field).to_string(), enabled);
                        if enabled {
                            let width = dialog_dimension(interface, document, "shading-width");
                            let height = dialog_dimension(interface, document, "shading-height");
                            commands.push(Box::new(CreateShadingTextureCommand::new(
                                name.clone(),
                                width,
                                height,
                                default_shading_color(&name),
                            )));
                        } else {
                            commands.push(Box::new(SetMapShadingTextureEnabledCommand::new(
                                name, false,
                            )));
                        }
                        self.shading_source = None;
                    }
                }
            }
        }
        if self.dialog.is_some() && self.shading_source == Some(ShadingSource::Existing) {
            for id in self.shading_grid.drain_clicks() {
                if self
                    .shading_grid
                    .item(&id)
                    .is_some_and(|item| !item.is_directory)
                {
                    if let Some(name) = self.dialog.take() {
                        let Some((field, _, _)) = SHADING_TOGGLES
                            .iter()
                            .find(|(_, shading, _)| *shading == name)
                        else {
                            continue;
                        };
                        self.shading_enabled.insert((*field).to_string(), true);
                        self.shading_source = None;
                        if let Some(c) = ImportShadingImageCommand::from_fields(serde_json::json!({
                            "texType": name,
                            "texturePath": id,
                        })) {
                            commands.push(Box::new(c));
                        }
                    }
                }
            }
        } else {
            self.shading_grid.drain_clicks();
        }
        self.render_shading_fields(interface, document);
        self.render_dialog(interface, document);
        commands
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
            self.shading_enabled
                .insert((*field).to_string(), textures.texture(shading).is_some());
        }
    }

    crate::sb_field_editor_methods!();
}

fn dialog_dimension(interface: &NativeInterfaceRef, document: u64, id: &str) -> i32 {
    element_by_id(interface, document, id)
        .and_then(|element| interface.rml_ui().element_get_value(element).ok().flatten())
        .and_then(|value| value.parse().ok())
        .filter(|value: &i32| *value > 0)
        .unwrap_or(1024)
}

fn default_shading_color(name: &str) -> [f32; 4] {
    match name {
        "splat_distr" => [1.0, 0.0, 0.0, 0.0],
        name if name.starts_with("splat_normals") => [0.5, 0.5, 1.0, 0.5],
        "emission" | "refl" => [0.0, 0.0, 0.0, 0.2],
        _ => [0.0, 0.0, 0.0, 1.0],
    }
}
