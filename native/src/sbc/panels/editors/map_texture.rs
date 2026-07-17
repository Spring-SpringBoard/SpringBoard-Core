use spring_native::prelude::{Error, NativeInterfaceRef};

use std::cell::RefCell;
use std::collections::BTreeMap;
use std::rc::Rc;

use crate::sbc::command_system::command::Command;
use crate::sbc::command_system::model::Models;
use crate::sbc::panels::editor::Editor;
use crate::sbc::panels::editor_base::{FieldSet, Layout};
use crate::sbc::panels::editors::brush::{
    non_empty, pattern_field, BrushAction, BrushActions, ASSETS,
};
use crate::sbc::panels::field::{ChangeQueue, FieldValue, InteractionQueue};
use crate::sbc::panels::fields::{BooleanField, ChoiceField, ColorField, NumericField};
use crate::sbc::panels::grid::{list_assets, GridItem, GridView};
use crate::sbc::panels::registry::{EditorSpec, Tab};
use crate::sbc::rml::{element_by_id, escape_rml};
use crate::sbc::states::{BrushKind, BrushSettings};

// Mirrors TextureEditor:Register in scen_edit/view/map/texture_editor.lua.
inventory::submit! {
    EditorSpec {
        name: "textureEditor",
        tab: Tab::Map,
        order: 2,
        caption: "Texture",
        tooltip: "Edit textures",
        image: "LuaUI/images/scenedit/palette.png",
        make: || Box::new(TextureEditor::new()),
    }
}

/// Blend modes, in the order `texture_editor.lua` lists them.
const MODES: &[&str] = &[
    "Normal",
    "Darken",
    "Lighten",
    "SoftLight",
    "HardLight",
    "Luminance",
    "Multiply",
    "Premultiplied",
    "Overlay",
    "Screen",
    "Add",
    "Subtract",
    "Difference",
    "InverseDifference",
    "Exclusion",
    "Color",
    "ColorBurn",
    "ColorDodge",
];

const KERNELS: &[&str] = &[
    "blur",
    "bottom_sobel",
    "emboss",
    "left_sobel",
    "outline",
    "right_sobel",
    "sharpen",
    "top sobel",
];

const ACTIONS: &[BrushAction] = &[
    BrushAction {
        caption: "Paint",
        image: "LuaUI/images/scenedit/large-paint-brush.png",
        kind: BrushKind::Texture,
        paint_mode: "paint",
    },
    BrushAction {
        caption: "Filter",
        image: "LuaUI/images/scenedit/filter-brush.png",
        kind: BrushKind::Texture,
        paint_mode: "blur",
    },
    BrushAction {
        caption: "DNTS",
        image: "LuaUI/images/scenedit/paint-brush.png",
        kind: BrushKind::Texture,
        paint_mode: "dnts",
    },
    BrushAction {
        caption: "Void",
        image: "LuaUI/images/scenedit/large-paint-brush.png",
        kind: BrushKind::Texture,
        paint_mode: "void",
    },
];

/// A material's channels, as `TextureManager.materialTextures` defines them: one
/// texture per channel, found by suffix next to the diffuse.
///
/// `normal` is a channel of every material but has no enable toggle, exactly as
/// Lua skips it when it builds the checkboxes.
const CHANNELS: &[(&str, &str, bool)] = &[
    ("diffuse", "Diffuse", true),
    ("specular", "Specular", true),
    ("normal", "Normal", false),
    ("emission", "Emission", true),
    ("refl", "Refl", true),
];

const IMAGE_EXTS: &[&str] = &[".png", ".jpg", ".tga", ".dds", ".bmp"];

/// The engine exposes at most four DNTS (splat normal) channels.
const DNTS_COUNT: i32 = 4;

/// Texture-channel toggles are intentionally two balanced rows. Four toggles
/// in one row made their captions and switches cramped in the 500dp panel.
const CHANNEL_TOGGLE_ROW_ONE: &[&str] = &["diffuseEnabled", "specularEnabled"];
const CHANNEL_TOGGLE_ROW_TWO: &[&str] = &["emissionEnabled", "reflEnabled"];

fn toggle_channels() -> impl Iterator<Item = &'static str> {
    CHANNELS
        .iter()
        .filter(|(_, _, toggle)| *toggle)
        .map(|(channel, _, _)| *channel)
}

/// One material: its name, and the channel textures that exist for it.
#[derive(Clone)]
struct Material {
    /// The bare material name (`dirt1`), which is what the picker shows.
    name: String,
    channels: BTreeMap<String, String>,
}

struct SavedBrush {
    id: String,
    material: String,
    brush: BrushSettings,
}

const ADD_BRUSH_ID: &str = "__add_saved_brush__";

/// The material a texture belongs to: its file name with the channel suffix
/// stripped, and without the directory. `.../brush_textures/dirt1_diffuse.png`
/// is the `diffuse` of `dirt1`.
fn material_of(path: &str) -> Option<(String, &'static str)> {
    let file = path.rsplit('/').next()?;
    let stem = file.rsplit_once('.').map(|(s, _)| s).unwrap_or(file);
    for (channel, _, _) in CHANNELS {
        if let Some(base) = stem.strip_suffix(&format!("_{channel}")) {
            return Some((base.to_string(), channel));
        }
    }
    None
}

/// Group the files under `brush_textures/` into materials. A material exists if
/// it has a diffuse; the other channels are optional, which is why the picker
/// shows which ones were found.
fn list_materials(interface: &NativeInterfaceRef) -> Vec<Material> {
    let root = format!("{ASSETS}/brush_textures");
    let mut found: BTreeMap<String, BTreeMap<String, String>> = BTreeMap::new();

    for item in list_assets(interface, &root, IMAGE_EXTS) {
        if item.is_directory {
            continue;
        }
        if let Some((name, channel)) = material_of(&item.id) {
            found
                .entry(name)
                .or_default()
                .insert(channel.to_string(), item.id.clone());
        }
    }

    found
        .into_iter()
        .filter(|(_, channels)| channels.contains_key("diffuse"))
        .map(|(name, channels)| Material { name, channels })
        .collect()
}

fn material_tooltip(material: &Material) -> String {
    let channel = |name: &str, title: &str| {
        let (color, mark) = if material.channels.contains_key(name) {
            ("#63d483", "&#10003;")
        } else {
            ("#ef6b6b", "&#10007;")
        };
        format!(
            "<div>{title}: <span style=\"color: {color};\">{mark}</span></div>",
            title = escape_rml(title),
        )
    };
    format!(
        "<div>{}</div>{}{}{}",
        escape_rml(&material.name),
        channel("diffuse", "Diffuse"),
        channel("normal", "Normal"),
        channel("specular", "Specular"),
    )
}

fn section_markup(id: &str, caption: &str) -> String {
    format!(
        r#"<div id="{id}" class="field-section"><div class="field-section-label">{caption}</div><div class="field-section-line"></div></div>"#,
        id = escape_rml(id),
        caption = escape_rml(caption),
    )
}

fn material_dialog_markup(material_grid: &GridView) -> String {
    format!(
        concat!(
            r#"<div id="texture-material-dialog" class="picker-backdrop hidden">"#,
            r#"<div class="dialog picker-dialog asset-dialog">"#,
            r#"<div class="dialog-header"><span class="dialog-title">Select material for new brush</span></div>"#,
            r#"<div class="dialog-content">{grid}</div>"#,
            r#"<div class="dialog-footer"><button id="texture-material-cancel" class="dialog-button">Cancel</button></div>"#,
            r#"</div></div>"#,
        ),
        grid = material_grid.container_rml(),
    )
}

#[derive(Debug, Clone, Copy)]
enum MaterialPickerEvent {
    Cancel,
}

/// The texture brush: a pattern, a material, and how it is blended in.
pub(crate) struct TextureEditor {
    fields: FieldSet,
    actions: BrushActions,
    pattern_grid: GridView,
    saved_brush_grid: GridView,
    material_grid: GridView,
    materials: Vec<Material>,
    /// The picked material: its name (what the grid highlights) and its channel
    /// textures, which the brush carries whole.
    selected_material: Option<String>,
    selected: BTreeMap<String, String>,
    saved_brushes: Vec<SavedBrush>,
    selected_brush: Option<String>,
    material_picker_open: bool,
    material_picker_events: Rc<RefCell<Vec<MaterialPickerEvent>>>,
    /// Which DNTS channels the map actually has. Lua disables the button when
    /// there are none.
    dnts_available: Vec<i32>,
    document: Option<u64>,
}

fn items(values: &[&str]) -> Vec<String> {
    values.iter().map(|v| v.to_string()).collect()
}

impl TextureEditor {
    pub(crate) fn new() -> Self {
        let mut fields: Vec<Box<dyn crate::sbc::panels::field::Field>> = vec![
            pattern_field(),
            Box::new(
                NumericField::new("size", "Size", 100.0)
                    .min(1.0)
                    .max(5000.0),
            ),
            Box::new(
                NumericField::new("rotation", "Rotation", 0.0)
                    .min(-360.0)
                    .max(360.0),
            ),
            Box::new(
                NumericField::new("texScale", "Scale", 2.0)
                    .min(0.01)
                    .step(0.05)
                    .decimals(2),
            ),
            Box::new(
                NumericField::new("texRotation", "Tex rotation", 0.0)
                    .min(-360.0)
                    .max(360.0),
            ),
            Box::new(
                NumericField::new("texOffsetX", "X", 0.0)
                    .min(-1.0)
                    .max(1.0)
                    .step(0.001)
                    .decimals(3),
            ),
            Box::new(
                NumericField::new("texOffsetY", "Y", 0.0)
                    .min(-1.0)
                    .max(1.0)
                    .step(0.001)
                    .decimals(3),
            ),
            Box::new(ChoiceField::new("mode", "Mode", items(MODES))),
            Box::new(ChoiceField::new("kernelMode", "Filter", items(KERNELS))),
            Box::new(
                NumericField::new("strength", "Strength", 1.0)
                    .min(0.0)
                    .max(1.0)
                    .step(0.05)
                    .decimals(2),
            ),
            Box::new(
                NumericField::new("falloffFactor", "Falloff", 0.3)
                    .min(0.0)
                    .max(1.0)
                    .step(0.05)
                    .decimals(2),
            ),
            Box::new(
                NumericField::new("featureFactor", "Feature", 1.0)
                    .min(0.0)
                    .max(1.0)
                    .step(0.05)
                    .decimals(2),
            ),
            Box::new(
                NumericField::new("value", "Value", 1.0)
                    .min(0.0)
                    .max(1.0)
                    .step(0.05)
                    .decimals(2),
            ),
            Box::new(
                NumericField::new("voidFactor", "Transparency", 1.0)
                    .min(0.0)
                    .max(1.0)
                    .step(0.05)
                    .decimals(2),
            ),
            Box::new(
                NumericField::new("splatTexScale", "Scale", 1.0)
                    .step(0.000_001)
                    .decimals(6),
            ),
            Box::new(
                NumericField::new("splatTexMult", "Mult", 0.5)
                    .step(0.01)
                    .decimals(2),
            ),
            Box::new(
                NumericField::new("dntsIndex", "DNTS", 0.0)
                    .min(0.0)
                    .max((DNTS_COUNT - 1) as f32)
                    .decimals(0),
            ),
            Box::new(BooleanField::new("exclusive", "Exclusive", false)),
            Box::new(ColorField::new("diffuseColor", "Color")),
        ];
        for (channel, title, toggle) in CHANNELS {
            if *toggle {
                fields.push(Box::new(BooleanField::new(
                    &enabled_name(channel),
                    title,
                    true,
                )));
            }
        }
        TextureEditor {
            actions: BrushActions::new(ACTIONS),
            fields: FieldSet::new(fields),
            pattern_grid: {
                let mut grid = GridView::new("texture-pattern-grid", 64);
                grid.configure_asset_navigation("brush_patterns/terrain/", IMAGE_EXTS);
                grid
            },
            saved_brush_grid: GridView::new("texture-saved-brush-grid", 64),
            material_grid: GridView::new("texture-material-grid", 64),
            materials: Vec::new(),
            selected_material: None,
            selected: BTreeMap::new(),
            saved_brushes: Vec::new(),
            selected_brush: None,
            material_picker_open: false,
            material_picker_events: Rc::new(RefCell::new(Vec::new())),
            dnts_available: Vec::new(),
            document: None,
        }
    }

    /// The current paint mode, which decides both what is painted and which
    /// fields are meaningful (Lua's `SetInvisibleFields` per action button).
    fn paint_mode(&self) -> &str {
        self.actions.selected_paint_mode().unwrap_or("paint")
    }

    fn render_grids(&mut self, interface: &NativeInterfaceRef, document: u64) -> Result<(), Error> {
        let pattern = self.fields.text("patternTexture");
        self.pattern_grid
            .set_selected((!pattern.is_empty()).then_some(pattern.as_str()));
        self.pattern_grid.render(interface, document)?;

        if self.materials.is_empty() {
            self.materials = list_materials(interface);
        }

        let mut saved_items = vec![GridItem {
            id: ADD_BRUSH_ID.to_string(),
            caption: "Add".to_string(),
            image: Some("LuaUI/images/scenedit/plus.png".to_string()),
            is_directory: false,
            tooltip: Some("Add new saved brush".to_string()),
            tooltip_markup: None,
        }];
        for saved in &self.saved_brushes {
            let material = self.materials.iter().find(|m| m.name == saved.material);
            saved_items.push(GridItem {
                id: saved.id.clone(),
                caption: saved.material.clone(),
                image: material.and_then(|m| m.channels.get("diffuse").cloned()),
                is_directory: false,
                tooltip: material.map(|m| format!("Saved brush: {}", m.name)),
                tooltip_markup: material.map(material_tooltip),
            });
        }
        self.saved_brush_grid.set_items(saved_items);
        self.saved_brush_grid
            .set_selected(self.selected_brush.as_deref());
        self.saved_brush_grid.render(interface, document)?;

        // Show the diffuse, and say which channels the material actually ships --
        // Lua's material tooltip.
        let items: Vec<GridItem> = self
            .materials
            .iter()
            .map(|material| GridItem {
                id: material.name.clone(),
                caption: material.name.clone(),
                image: material.channels.get("diffuse").cloned(),
                is_directory: false,
                tooltip: None,
                tooltip_markup: Some(material_tooltip(material)),
            })
            .collect();
        self.material_grid.set_items(items);
        self.material_grid
            .set_selected(self.selected_material.as_deref());
        self.material_grid.render(interface, document)
    }

    /// Hide the fields the current mode does not use, as Lua does when each
    /// action button is pressed.
    fn apply_visibility(&self, interface: &NativeInterfaceRef) {
        let Some(doc) = self.document else {
            return;
        };
        let mode = self.paint_mode();

        let material = matches!(mode, "paint");
        let hidden: &[(&str, bool)] = &[
            ("mode", !material),
            ("texScale", !material),
            ("texRotation", !material),
            ("texOffsetX", !material),
            ("texOffsetY", !material),
            ("featureFactor", !material),
            ("diffuseColor", !material),
            ("kernelMode", mode != "blur"),
            ("splatTexScale", mode != "dnts"),
            ("splatTexMult", mode != "dnts"),
            ("value", mode != "dnts"),
            ("dntsIndex", mode != "dnts"),
            ("exclusive", mode != "dnts"),
            ("voidFactor", mode != "void"),
            ("strength", mode == "void"),
            ("falloffFactor", mode == "blur"),
        ];
        for (name, hide) in hidden {
            if let Some(elem) = element_by_id(interface, doc, &format!("row-{name}")) {
                let _ = interface.rml_ui().element_set_class(elem, "hidden", *hide);
            }
        }
        for channel in toggle_channels() {
            if let Some(elem) =
                element_by_id(interface, doc, &format!("row-{}", enabled_name(channel)))
            {
                let _ = interface
                    .rml_ui()
                    .element_set_class(elem, "hidden", !material);
            }
        }
        for (id, visible) in [
            ("texture-saved-brush-section", material),
            ("texture-saved-brush-grid", material),
            (
                "texture-material-dialog",
                material && self.material_picker_open,
            ),
            ("texture-splat-section", mode == "dnts"),
        ] {
            if let Some(elem) = element_by_id(interface, doc, id) {
                let _ = interface
                    .rml_ui()
                    .element_set_class(elem, "hidden", !visible);
            }
        }
    }

    fn take_grid_clicks(
        &mut self,
        interface: &NativeInterfaceRef,
        document: u64,
    ) -> Result<bool, Error> {
        let mut changed = false;
        for id in self.saved_brush_grid.drain_clicks() {
            if id == ADD_BRUSH_ID && self.paint_mode() == "paint" {
                self.material_picker_open = true;
                changed = true;
            } else if self.saved_brushes.iter().any(|brush| brush.id == id) {
                self.load_saved_brush(&id, interface);
                changed = true;
            }
        }
        for event in self.material_picker_events.borrow_mut().drain(..) {
            match event {
                MaterialPickerEvent::Cancel => {
                    self.material_picker_open = false;
                    changed = true;
                }
            }
        }
        for id in self.pattern_grid.drain_asset_clicks(interface, document)? {
            self.fields.set("patternTexture", FieldValue::Text(id));
            changed = true;
        }
        for id in self.material_grid.drain_clicks() {
            if let Some((material_name, channels)) = self
                .materials
                .iter()
                .find(|m| m.name == id)
                .map(|material| (material.name.clone(), material.channels.clone()))
            {
                self.selected = channels;
                self.selected_material = Some(material_name.clone());
                if self.material_picker_open {
                    self.create_saved_brush(material_name);
                    self.material_picker_open = false;
                }
                changed = true;
            }
        }
        Ok(changed)
    }

    fn create_saved_brush(&mut self, material: String) {
        let id = format!("saved-brush-{}", self.saved_brushes.len() + 1);
        let mut brush = self.brush_from_fields();
        brush.brush_textures = self.selected.clone();
        brush.brush_texture = self.selected.get("diffuse").cloned();
        self.saved_brushes.push(SavedBrush {
            id: id.clone(),
            material,
            brush,
        });
        self.selected_brush = Some(id);
    }

    fn brush_from_fields(&self) -> BrushSettings {
        let mut brush = BrushSettings::default();
        self.write_brush(&mut brush);
        brush
    }

    fn load_saved_brush(&mut self, id: &str, interface: &NativeInterfaceRef) {
        let Some(saved) = self.saved_brushes.iter().find(|brush| brush.id == id) else {
            return;
        };
        let brush = saved.brush.clone();
        self.selected_brush = Some(id.to_string());
        self.selected_material = Some(saved.material.clone());
        self.selected = brush.brush_textures.clone();
        self.fields.set(
            "patternTexture",
            FieldValue::Text(brush.pattern_texture.clone().unwrap_or_default()),
        );
        self.fields.set("size", FieldValue::Number(brush.size));
        self.fields
            .set("rotation", FieldValue::Number(brush.rotation));
        self.fields
            .set("texScale", FieldValue::Number(brush.tex_scale));
        self.fields
            .set("texRotation", FieldValue::Number(brush.tex_rotation));
        self.fields
            .set("texOffsetX", FieldValue::Number(brush.tex_offset_x));
        self.fields
            .set("texOffsetY", FieldValue::Number(brush.tex_offset_y));
        self.fields.set("mode", FieldValue::Text(brush.mode));
        self.fields
            .set("kernelMode", FieldValue::Text(brush.kernel_mode));
        self.fields
            .set("strength", FieldValue::Number(brush.strength));
        self.fields
            .set("falloffFactor", FieldValue::Number(brush.falloff_factor));
        self.fields
            .set("featureFactor", FieldValue::Number(brush.feature_factor));
        self.fields.set("value", FieldValue::Number(brush.value));
        self.fields
            .set("voidFactor", FieldValue::Number(brush.void_factor));
        self.fields
            .set("splatTexScale", FieldValue::Number(brush.splat_tex_scale));
        self.fields
            .set("splatTexMult", FieldValue::Number(brush.splat_tex_mult));
        self.fields
            .set("exclusive", FieldValue::Bool(brush.exclusive));
        self.fields
            .set("diffuseColor", FieldValue::Color(brush.diffuse_color));
        self.fields.set(
            "dntsIndex",
            FieldValue::Number((brush.color_index - 1) as f32),
        );
        for channel in toggle_channels() {
            self.fields.set(
                &enabled_name(channel),
                FieldValue::Bool(brush.texture_enabled.get(channel).copied().unwrap_or(true)),
            );
        }
        let _ = self.fields.write_values(interface);
    }

    fn update_selected_saved_brush(&mut self) {
        let Some(id) = self.selected_brush.as_deref() else {
            return;
        };
        let brush = self.brush_from_fields();
        if let Some(saved) = self.saved_brushes.iter_mut().find(|saved| saved.id == id) {
            saved.brush = brush;
        }
    }
}

impl Editor for TextureEditor {
    fn generate_rml(&self) -> String {
        self.fields.generate_rml(&[
            Layout::Raw(self.actions.generate_rml()),
            Layout::Raw(section_markup(
                "texture-saved-brush-section",
                "Saved brushes",
            )),
            Layout::Raw(self.saved_brush_grid.container_rml()),
            Layout::Raw(section_markup("texture-pattern-section", "Pattern")),
            Layout::Raw(self.pattern_grid.container_rml()),
            Layout::IdentifiedGroup(&["size", "rotation", "texScale"]),
            Layout::IdentifiedGroup(CHANNEL_TOGGLE_ROW_ONE),
            Layout::IdentifiedGroup(CHANNEL_TOGGLE_ROW_TWO),
            Layout::IdentifiedGroup(&["texRotation", "texOffsetX", "texOffsetY"]),
            Layout::IdentifiedField("diffuseColor"),
            Layout::IdentifiedField("mode"),
            Layout::IdentifiedField("kernelMode"),
            Layout::Section("Blending"),
            Layout::IdentifiedGroup(&["strength", "falloffFactor", "featureFactor"]),
            Layout::IdentifiedField("value"),
            Layout::IdentifiedField("voidFactor"),
            Layout::Raw(section_markup("texture-splat-section", "Splat")),
            Layout::IdentifiedGroup(&["splatTexScale", "splatTexMult"]),
            Layout::IdentifiedField("dntsIndex"),
            Layout::IdentifiedField("exclusive"),
        ])
    }

    fn refresh_from_engine(&mut self, interface: &NativeInterfaceRef, _models: &mut Models) {
        // A map with no splat normals has no DNTS to paint, so Lua greys the
        // button out rather than letting the brush no-op.
        self.dnts_available = (0..DNTS_COUNT)
            .filter(|i| {
                interface
                    .gfx()
                    .texture_info(&format!("$ssmf_splat_normals:{i}"))
                    .is_ok_and(|(width, ..)| width > 0)
            })
            .collect();
    }

    fn bind_fields(
        &mut self,
        interface: &NativeInterfaceRef,
        document: u64,
        changes: &ChangeQueue,
        interactions: &InteractionQueue,
    ) -> Result<(), Error> {
        self.document = Some(document);
        self.actions
            .set_enabled(interface, document, "DNTS", !self.dnts_available.is_empty());
        self.actions.bind(interface, document)?;
        self.fields
            .bind(interface, document, changes, interactions)?;
        self.pattern_grid.refresh_navigation(interface, document)?;
        if let Some(host) = element_by_id(interface, document, "texture-material-modal") {
            interface
                .rml_ui()
                .element_set_inner_rml(host, &material_dialog_markup(&self.material_grid))?;
        }
        if let Some(cancel) = element_by_id(interface, document, "texture-material-cancel") {
            let events = self.material_picker_events.clone();
            interface
                .rml_ui()
                .element_add_event_listener(cancel, "click", false, move || {
                    events.borrow_mut().push(MaterialPickerEvent::Cancel);
                })?;
        }
        self.render_grids(interface, document)?;
        self.apply_visibility(interface);
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
        self.fields.read(name, interface);
        vec![]
    }

    fn process_drag_end(&mut self, _name: &str) -> Vec<Box<dyn Command>> {
        vec![]
    }

    fn tick(&mut self, interface: &NativeInterfaceRef, document: u64) -> Vec<Box<dyn Command>> {
        let mode_before = self.paint_mode().to_string();
        self.actions.tick(interface, document);
        if self.paint_mode() != "paint" && self.material_picker_open {
            self.material_picker_open = false;
        }
        if self.take_grid_clicks(interface, document).unwrap_or(false) {
            let _ = self.fields.write_values(interface);
            let _ = self.render_grids(interface, document);
            self.apply_visibility(interface);
        }
        if self.paint_mode() != mode_before {
            self.apply_visibility(interface);
        }
        if !self.material_picker_open {
            self.update_selected_saved_brush();
        }
        vec![]
    }

    fn take_state_request(&mut self) -> Option<crate::sbc::states::StateRequest> {
        self.actions.take_request()
    }

    fn clear_state_selection(&mut self, interface: &NativeInterfaceRef, document: u64) {
        self.actions.clear(interface, document);
    }

    fn has_open_modal(&self) -> bool {
        self.material_picker_open
    }

    fn write_brush(&self, brush: &mut BrushSettings) {
        brush.size = self.fields.number("size");
        brush.rotation = self.fields.number("rotation");
        brush.tex_scale = self.fields.number("texScale");
        brush.tex_rotation = self.fields.number("texRotation");
        brush.tex_offset_x = self.fields.number("texOffsetX");
        brush.tex_offset_y = self.fields.number("texOffsetY");
        brush.strength = self.fields.number("strength");
        brush.falloff_factor = self.fields.number("falloffFactor");
        brush.feature_factor = self.fields.number("featureFactor");
        brush.value = self.fields.number("value");
        brush.void_factor = self.fields.number("voidFactor");
        brush.splat_tex_scale = self.fields.number("splatTexScale");
        brush.splat_tex_mult = self.fields.number("splatTexMult");
        brush.mode = self.fields.text("mode");
        brush.kernel_mode = self.fields.text("kernelMode");
        brush.exclusive = self.fields.boolean("exclusive");
        brush.pattern_texture = non_empty(self.fields.text("patternTexture"));
        if let FieldValue::Color(rgba) = self.fields.value("diffuseColor") {
            brush.diffuse_color = rgba;
        }
        // Lua's colorIndex is the 1-based DNTS channel.
        brush.color_index = self.fields.number("dntsIndex") as i32 + 1;

        // The brush carries the whole material; the flags say which of its
        // channels are painted.
        brush.brush_textures = self.selected.clone();
        brush.brush_texture = self.selected.get("diffuse").cloned();
        brush.texture_enabled = toggle_channels()
            .map(|channel| {
                (
                    channel.to_string(),
                    self.fields.boolean(&enabled_name(channel)),
                )
            })
            .collect();
    }

    fn read_brush(&mut self, brush: &BrushSettings, interface: &NativeInterfaceRef) {
        self.fields.set("size", FieldValue::Number(brush.size));
        self.fields
            .set("rotation", FieldValue::Number(brush.rotation));
        let _ = self.fields.write_values(interface);
    }

    crate::sb_field_editor_methods!();
}

fn enabled_name(channel: &str) -> String {
    format!("{channel}Enabled")
}

#[cfg(test)]
mod tests {
    use super::*;

    /// The VFS hands back full paths, so the material's name is the file's, not
    /// the path's -- every material was captioned "springboard" until it was.
    #[test]
    fn a_material_is_named_after_its_file_not_its_path() {
        let (name, channel) =
            material_of("springboard/assets/core/brush_textures/dirt1_diffuse.png").unwrap();
        assert_eq!(name, "dirt1");
        assert_eq!(channel, "diffuse");

        let (name, channel) =
            material_of("springboard/assets/core/brush_textures/cement_normal.png").unwrap();
        assert_eq!(name, "cement");
        assert_eq!(channel, "normal");
    }

    #[test]
    fn a_texture_with_no_channel_suffix_belongs_to_no_material() {
        assert!(material_of("brush_textures/readme.png").is_none());
    }

    #[test]
    fn normal_is_a_channel_but_has_no_toggle() {
        let toggles: Vec<&str> = toggle_channels().collect();
        assert!(!toggles.contains(&"normal"));
        assert!(toggles.contains(&"diffuse"));
        assert!(CHANNELS.iter().any(|(c, _, _)| *c == "normal"));
    }
}
