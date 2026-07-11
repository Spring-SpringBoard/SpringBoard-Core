use spring_native::prelude::{Error, NativeInterfaceRef};

use std::collections::BTreeMap;

use crate::sbc::command_system::model::Models;
use crate::sbc::panels::editor::Editor;
use crate::sbc::panels::editor_base::{FieldSet, Layout};
use crate::sbc::rml::element_by_id;
use crate::sbc::panels::editors::brush::{
    non_empty, pattern_field, BrushAction, BrushActions, ASSETS,
};
use crate::sbc::panels::field::{ChangeQueue, FieldValue, InteractionQueue};
use crate::sbc::panels::fields::{BooleanField, ChoiceField, ColorField, NumericField};
use crate::sbc::panels::grid::{list_assets, GridItem, GridView};
use crate::sbc::panels::registry::{EditorSpec, Tab};
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

fn toggle_channels() -> impl Iterator<Item = &'static str> {
    CHANNELS
        .iter()
        .filter(|(_, _, toggle)| *toggle)
        .map(|(channel, _, _)| *channel)
}

/// One material: a base name under `brush_textures/` and the channel textures
/// that exist for it.
#[derive(Clone)]
struct Material {
    name: String,
    channels: BTreeMap<String, String>,
}

/// Group the files under `brush_textures/` into materials by stripping the
/// channel suffix. A material exists if it has a diffuse; the other channels are
/// optional, which is why the picker shows which ones were found.
fn list_materials(interface: &NativeInterfaceRef) -> Vec<Material> {
    let root = format!("{ASSETS}/brush_textures");
    let mut found: BTreeMap<String, BTreeMap<String, String>> = BTreeMap::new();

    for item in list_assets(interface, &root, IMAGE_EXTS) {
        if item.is_directory {
            continue;
        }
        let stem = item.id.rsplit_once('.').map(|(s, _)| s).unwrap_or(&item.id);
        for (channel, _, _) in CHANNELS {
            let suffix = format!("_{channel}");
            if let Some(base) = stem.strip_suffix(&suffix) {
                found
                    .entry(base.to_string())
                    .or_default()
                    .insert((*channel).to_string(), item.id.clone());
                break;
            }
        }
    }

    found
        .into_iter()
        .filter(|(_, channels)| channels.contains_key("diffuse"))
        .map(|(name, channels)| Material { name, channels })
        .collect()
}

/// The texture brush: a pattern, a material, and how it is blended in.
pub(crate) struct TextureEditor {
    fields: FieldSet,
    actions: BrushActions,
    pattern_grid: GridView,
    material_grid: GridView,
    materials: Vec<Material>,
    /// The picked material: its name (what the grid highlights) and its channel
    /// textures, which the brush carries whole.
    selected_material: Option<String>,
    selected: BTreeMap<String, String>,
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
            pattern_grid: GridView::new("texture-pattern-grid", 64),
            material_grid: GridView::new("texture-material-grid", 64),
            materials: Vec::new(),
            selected_material: None,
            selected: BTreeMap::new(),
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
        self.pattern_grid.set_items(list_assets(
            interface,
            &format!("{ASSETS}/brush_patterns/terrain"),
            IMAGE_EXTS,
        ));
        self.pattern_grid
            .set_selected((!pattern.is_empty()).then_some(pattern.as_str()));
        self.pattern_grid.render(interface, document)?;

        if self.materials.is_empty() {
            self.materials = list_materials(interface);
        }
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
                tooltip: Some(format!(
                    "{}: {}",
                    material.name,
                    material
                        .channels
                        .keys()
                        .cloned()
                        .collect::<Vec<_>>()
                        .join(", ")
                )),
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
        // The material picker only means anything while painting a material.
        for id in ["texture-material-grid"] {
            if let Some(elem) = element_by_id(interface, doc, id) {
                let _ = interface
                    .rml_ui()
                    .element_set_class(elem, "hidden", !material);
            }
        }
    }

    fn take_grid_clicks(&mut self) -> bool {
        let mut changed = false;
        for id in self.pattern_grid.drain_clicks() {
            if self.pattern_grid.item(&id).is_some_and(|i| !i.is_directory) {
                self.fields.set("patternTexture", FieldValue::Text(id));
                changed = true;
            }
        }
        for id in self.material_grid.drain_clicks() {
            if let Some(material) = self.materials.iter().find(|m| m.name == id) {
                self.selected = material.channels.clone();
                self.selected_material = Some(id);
                changed = true;
            }
        }
        changed
    }
}

impl Editor for TextureEditor {
    fn generate_rml(&self) -> String {
        let channel_toggles: Vec<String> = toggle_channels().map(enabled_name).collect();
        self.fields.generate_rml(&[
            Layout::Raw(self.actions.generate_rml()),
            Layout::Section("Pattern"),
            Layout::Field("patternTexture"),
            Layout::Raw(self.pattern_grid.container_rml()),
            Layout::IdentifiedGroup(&["size", "rotation", "texScale"]),
            Layout::Section("Material"),
            Layout::Raw(self.material_grid.container_rml()),
            Layout::IdentifiedGroup(&channel_toggles.iter().map(String::as_str).collect::<Vec<_>>()),
            Layout::IdentifiedGroup(&["texRotation", "texOffsetX", "texOffsetY"]),
            Layout::IdentifiedField("diffuseColor"),
            Layout::IdentifiedField("mode"),
            Layout::IdentifiedField("kernelMode"),
            Layout::Section("Blending"),
            Layout::IdentifiedGroup(&["strength", "falloffFactor", "featureFactor"]),
            Layout::IdentifiedField("value"),
            Layout::IdentifiedField("voidFactor"),
            Layout::Section("Splat"),
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
        self.actions.bind(interface, document)?;
        self.actions
            .set_enabled(interface, document, "DNTS", !self.dnts_available.is_empty());
        self.fields
            .bind(interface, document, changes, interactions)?;
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
        _next: &mut u64,
    ) -> Vec<String> {
        self.fields.read(name, interface);
        vec![]
    }

    fn process_drag_end(&mut self, _name: &str, _next: &mut u64) -> Vec<String> {
        vec![]
    }

    fn tick(
        &mut self,
        interface: &NativeInterfaceRef,
        document: u64,
        _next: &mut u64,
    ) -> Vec<String> {
        let mode_before = self.paint_mode().to_string();
        self.actions.tick(interface, document);
        if self.take_grid_clicks() {
            let _ = self.fields.write_values(interface);
            let _ = self.render_grids(interface, document);
        }
        if self.paint_mode() != mode_before {
            self.apply_visibility(interface);
        }
        vec![]
    }

    fn take_state_request(&mut self) -> Option<crate::sbc::states::StateRequest> {
        self.actions.take_request()
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

    #[test]
    fn a_material_gathers_its_channels_and_needs_a_diffuse() {
        // list_materials needs the VFS, so exercise the grouping rule it applies.
        let files = [
            "dirt1_diffuse.png",
            "dirt1_normal.png",
            "dirt1_specular.png",
            "orphan_specular.png",
        ];
        let mut found: BTreeMap<String, BTreeMap<String, String>> = BTreeMap::new();
        for file in files {
            let stem = file.rsplit_once('.').unwrap().0;
            for (channel, _, _) in CHANNELS {
                if let Some(base) = stem.strip_suffix(&format!("_{channel}")) {
                    found
                        .entry(base.to_string())
                        .or_default()
                        .insert((*channel).to_string(), file.to_string());
                    break;
                }
            }
        }
        found.retain(|_, channels| channels.contains_key("diffuse"));

        assert_eq!(found.len(), 1, "a specular with no diffuse is not a material");
        let dirt = &found["dirt1"];
        assert_eq!(dirt.len(), 3);
        assert_eq!(dirt["diffuse"], "dirt1_diffuse.png");
        assert_eq!(dirt["normal"], "dirt1_normal.png");
    }

    #[test]
    fn normal_is_a_channel_but_has_no_toggle() {
        let toggles: Vec<&str> = toggle_channels().collect();
        assert!(!toggles.contains(&"normal"));
        assert!(toggles.contains(&"diffuse"));
        assert!(CHANNELS.iter().any(|(c, _, _)| *c == "normal"));
    }
}
