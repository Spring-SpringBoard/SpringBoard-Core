use spring_native::prelude::{Error, NativeInterfaceRef};

use std::cell::RefCell;
use std::collections::BTreeMap;
use std::rc::Rc;

use serde::{Deserialize, Serialize};

use crate::sbc::panels::brush::{non_empty, BrushAction, BrushActions};
use crate::sbc::panels::controls::grid::GridView;
use crate::sbc::panels::field::FieldValue;
use crate::sbc::panels::fields::{BooleanField, ChoiceField, ColorField, NumericField};
use crate::sbc::panels::runtime::{
    AssetGrid, AssetGridDef, Brush, EditorModel, FieldMut, FieldRef, TableEntry, TableModel,
};
use crate::sbc::project::{EditorState, TextureEditorState};
use crate::sbc::rml::escape_rml;
use crate::sbc::states::BrushSettings;
use crate::sbc::textures::materials::{Material, CHANNELS};

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

pub(super) const ACTIONS: &[BrushAction] = &[
    BrushAction {
        caption: "Paint",
        image: "LuaUI/images/scenedit/large-paint-brush.png",
        tool: &crate::sbc::textures::brushes::TEXTURE,
        paint_mode: "paint",
    },
    BrushAction {
        caption: "Filter",
        image: "LuaUI/images/scenedit/filter-brush.png",
        tool: &crate::sbc::textures::brushes::TEXTURE,
        paint_mode: "blur",
    },
    BrushAction {
        caption: "DNTS",
        image: "LuaUI/images/scenedit/paint-brush.png",
        tool: &crate::sbc::textures::brushes::TEXTURE,
        paint_mode: "dnts",
    },
    BrushAction {
        caption: "Void",
        image: "LuaUI/images/scenedit/large-paint-brush.png",
        tool: &crate::sbc::textures::brushes::TEXTURE,
        paint_mode: "void",
    },
];

/// The engine exposes at most four DNTS (splat normal) channels.
pub(super) const DNTS_COUNT: i32 = 4;

pub(super) fn toggle_channels() -> impl Iterator<Item = &'static str> {
    CHANNELS
        .iter()
        .filter(|(_, _, toggle)| *toggle)
        .map(|(channel, _, _)| *channel)
}

#[derive(Clone, Debug, Deserialize, Serialize)]
#[serde(rename_all = "camelCase")]
pub(crate) struct SavedBrush {
    pub(crate) id: String,
    pub(crate) material: String,
    pub(crate) brush: BrushSettings,
}

pub(super) const ADD_BRUSH_ID: &str = "__add_saved_brush__";

pub(super) fn material_tooltip(material: &Material) -> String {
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

pub(super) fn enabled_name(channel: &str) -> String {
    format!("{channel}Enabled")
}

#[derive(Debug, Clone, Copy)]
pub(super) enum MaterialPickerEvent {
    Cancel,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub(crate) enum TexField {
    Pattern,
    Size,
    Rotation,
    TexScale,
    TexRotation,
    TexOffsetX,
    TexOffsetY,
    Mode,
    KernelMode,
    Strength,
    FalloffFactor,
    FeatureFactor,
    Value,
    VoidFactor,
    SplatTexScale,
    SplatTexMult,
    DntsIndex,
    Exclusive,
    DiffuseColor,
    DiffuseEnabled,
    SpecularEnabled,
    EmissionEnabled,
    ReflEnabled,
}

use TexField::*;

static PATTERN: AssetGridDef = AssetGridDef {
    name: "patternTexture",
    container: "texture-pattern-grid",
    root: "brush_patterns/terrain/",
    extensions: &["png", "jpg", "tga", "dds", "bmp"],
    cell: 64,
    brush: Some(Brush::Pattern),
};

fn items(values: &[&str]) -> Vec<String> {
    values.iter().map(|v| v.to_string()).collect()
}

fn texture_table() -> TableModel<TexField> {
    let mut entries = vec![
        TableEntry {
            id: Size,
            field: Box::new(
                NumericField::new("size", "Size", 100.0)
                    .min(1.0)
                    .max(5000.0),
            ),
            brush: Some(Brush::Size),
        },
        TableEntry {
            id: Rotation,
            field: Box::new(
                NumericField::new("rotation", "Rotation", 0.0)
                    .min(-360.0)
                    .max(360.0),
            ),
            brush: Some(Brush::Rotation),
        },
        TableEntry::new(
            TexScale,
            Box::new(
                NumericField::new("texScale", "Scale", 2.0)
                    .min(0.01)
                    .step(0.05)
                    .decimals(2),
            ),
        ),
        TableEntry::new(
            TexRotation,
            Box::new(
                NumericField::new("texRotation", "Tex rotation", 0.0)
                    .min(-360.0)
                    .max(360.0),
            ),
        ),
        TableEntry::new(
            TexOffsetX,
            Box::new(
                NumericField::new("texOffsetX", "X", 0.0)
                    .min(-1.0)
                    .max(1.0)
                    .step(0.001)
                    .decimals(3),
            ),
        ),
        TableEntry::new(
            TexOffsetY,
            Box::new(
                NumericField::new("texOffsetY", "Y", 0.0)
                    .min(-1.0)
                    .max(1.0)
                    .step(0.001)
                    .decimals(3),
            ),
        ),
        TableEntry::new(
            Mode,
            Box::new(ChoiceField::new("mode", "Mode", items(MODES))),
        ),
        TableEntry::new(
            KernelMode,
            Box::new(ChoiceField::new("kernelMode", "Filter", items(KERNELS))),
        ),
        TableEntry::new(
            Strength,
            Box::new(
                NumericField::new("strength", "Strength", 1.0)
                    .min(0.0)
                    .max(1.0)
                    .step(0.05)
                    .decimals(2),
            ),
        ),
        TableEntry::new(
            FalloffFactor,
            Box::new(
                NumericField::new("falloffFactor", "Falloff", 0.3)
                    .min(0.0)
                    .max(1.0)
                    .step(0.05)
                    .decimals(2),
            ),
        ),
        TableEntry::new(
            FeatureFactor,
            Box::new(
                NumericField::new("featureFactor", "Feature", 1.0)
                    .min(0.0)
                    .max(1.0)
                    .step(0.05)
                    .decimals(2),
            ),
        ),
        TableEntry::new(
            Value,
            Box::new(
                NumericField::new("value", "Value", 1.0)
                    .min(0.0)
                    .max(1.0)
                    .step(0.05)
                    .decimals(2),
            ),
        ),
        TableEntry::new(
            VoidFactor,
            Box::new(
                NumericField::new("voidFactor", "Transparency", 1.0)
                    .min(0.0)
                    .max(1.0)
                    .step(0.05)
                    .decimals(2),
            ),
        ),
        TableEntry::new(
            SplatTexScale,
            Box::new(
                NumericField::new("splatTexScale", "Scale", 1.0)
                    .step(0.000_001)
                    .decimals(6),
            ),
        ),
        TableEntry::new(
            SplatTexMult,
            Box::new(
                NumericField::new("splatTexMult", "Mult", 0.5)
                    .step(0.01)
                    .decimals(2),
            ),
        ),
        TableEntry::new(
            DntsIndex,
            Box::new(
                NumericField::new("dntsIndex", "DNTS", 0.0)
                    .min(0.0)
                    .max((DNTS_COUNT - 1) as f32)
                    .decimals(0),
            ),
        ),
        TableEntry::new(
            Exclusive,
            Box::new(BooleanField::new("exclusive", "Exclusive", false)),
        ),
        TableEntry::new(
            DiffuseColor,
            Box::new(ColorField::new("diffuseColor", "Color")),
        ),
    ];
    for (channel, title, toggle) in CHANNELS {
        if !toggle {
            continue;
        }
        let id = match *channel {
            "diffuse" => DiffuseEnabled,
            "specular" => SpecularEnabled,
            "emission" => EmissionEnabled,
            _ => ReflEnabled,
        };
        entries.push(TableEntry::new(
            id,
            Box::new(BooleanField::new(&enabled_name(channel), title, true)),
        ));
    }
    TableModel::new(entries)
}

/// The texture brush: a pattern, a material, and how it is blended in.
pub(crate) struct TextureUiModel {
    pub(super) table: TableModel<TexField>,
    pub(super) actions: BrushActions,
    pattern: AssetGrid,
    pub(super) saved_brush_grid: GridView,
    pub(super) material_grid: GridView,
    pub(super) materials: Vec<Material>,
    /// The picked material: its name (what the grid highlights) and its channel
    /// textures, which the brush carries whole.
    pub(super) selected_material: Option<String>,
    selected: BTreeMap<String, String>,
    pub(super) saved_brushes: Vec<SavedBrush>,
    pub(super) selected_brush: Option<String>,
    pub(super) material_picker_open: bool,
    pub(super) material_picker_events: Rc<RefCell<Vec<MaterialPickerEvent>>>,
    /// Which DNTS channels the map actually has. Lua disables the button when
    /// there are none.
    pub(super) dnts_available: Vec<i32>,
}

impl TextureUiModel {
    pub(crate) fn new() -> Self {
        TextureUiModel {
            table: texture_table(),
            actions: BrushActions::new(ACTIONS),
            pattern: AssetGrid::of(&PATTERN),
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
        }
    }

    /// The current paint mode, which decides both what is painted and which
    /// fields are meaningful (Lua's `SetInvisibleFields` per action button).
    pub(super) fn paint_mode(&self) -> &str {
        self.actions.selected_paint_mode().unwrap_or("paint")
    }

    pub(super) fn take_grid_clicks(
        &mut self,
        interface: &NativeInterfaceRef,
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

    /// The brush state beyond the tagged size/rotation/pattern fields.
    pub(super) fn write_extra(&self, brush: &mut BrushSettings) {
        brush.tex_scale = self.number(TexScale);
        brush.tex_rotation = self.number(TexRotation);
        brush.tex_offset_x = self.number(TexOffsetX);
        brush.tex_offset_y = self.number(TexOffsetY);
        brush.strength = self.number(Strength);
        brush.falloff_factor = self.number(FalloffFactor);
        brush.feature_factor = self.number(FeatureFactor);
        brush.value = self.number(Value);
        brush.void_factor = self.number(VoidFactor);
        brush.splat_tex_scale = self.number(SplatTexScale);
        brush.splat_tex_mult = self.number(SplatTexMult);
        brush.mode = self.text(Mode);
        brush.kernel_mode = self.text(KernelMode);
        brush.exclusive = self.boolean(Exclusive);
        if let FieldValue::Color(rgba) = self.table.value(DiffuseColor) {
            brush.diffuse_color = rgba;
        }
        // Lua's colorIndex is the 1-based DNTS channel.
        brush.color_index = self.number(DntsIndex) as i32 + 1;

        // The brush carries the whole material; the flags say which of its
        // channels are painted.
        brush.brush_textures = self.selected.clone();
        brush.brush_texture = self.selected.get("diffuse").cloned();
        brush.texture_enabled = toggle_channels()
            .map(|channel| {
                let id = match channel {
                    "diffuse" => DiffuseEnabled,
                    "specular" => SpecularEnabled,
                    "emission" => EmissionEnabled,
                    _ => ReflEnabled,
                };
                (channel.to_string(), self.boolean(id))
            })
            .collect();
    }

    pub(super) fn update_selected_saved_brush(&mut self) {
        let Some(id) = self.selected_brush.as_deref() else {
            return;
        };
        let brush = self.brush_from_fields();
        if let Some(saved) = self.saved_brushes.iter_mut().find(|saved| saved.id == id) {
            saved.brush = brush;
        }
    }

    pub(super) fn load_editor_state(&mut self, state: &EditorState) {
        let saved = state.texture();
        self.saved_brushes = saved.saved_brushes.clone();
        self.selected_brush = saved.selected_brush.clone();
        self.selected_material = saved.selected_material.clone();
    }

    pub(super) fn save_editor_state(&self, state: &mut EditorState) {
        state.set_texture(TextureEditorState {
            saved_brushes: self.saved_brushes.clone(),
            selected_brush: self.selected_brush.clone(),
            selected_material: self.selected_material.clone(),
        });
    }

    pub(super) fn read_brush(&mut self, brush: &BrushSettings) {
        self.table
            .set(TexScale, FieldValue::Number(brush.tex_scale));
        self.table
            .set(TexRotation, FieldValue::Number(brush.tex_rotation));
        self.table
            .set(TexOffsetX, FieldValue::Number(brush.tex_offset_x));
        self.table
            .set(TexOffsetY, FieldValue::Number(brush.tex_offset_y));
        self.table.set(Mode, FieldValue::Text(brush.mode.clone()));
        self.table
            .set(KernelMode, FieldValue::Text(brush.kernel_mode.clone()));
        self.table.set(Strength, FieldValue::Number(brush.strength));
        self.table
            .set(FalloffFactor, FieldValue::Number(brush.falloff_factor));
        self.table
            .set(FeatureFactor, FieldValue::Number(brush.feature_factor));
        self.table.set(Value, FieldValue::Number(brush.value));
        self.table
            .set(VoidFactor, FieldValue::Number(brush.void_factor));
        self.table
            .set(SplatTexScale, FieldValue::Number(brush.splat_tex_scale));
        self.table
            .set(SplatTexMult, FieldValue::Number(brush.splat_tex_mult));
        self.table.set(Exclusive, FieldValue::Bool(brush.exclusive));
        self.table
            .set(DiffuseColor, FieldValue::Color(brush.diffuse_color));
        self.table.set(
            DntsIndex,
            FieldValue::Number((brush.color_index - 1) as f32),
        );
        for channel in toggle_channels() {
            let id = match channel {
                "diffuse" => DiffuseEnabled,
                "specular" => SpecularEnabled,
                "emission" => EmissionEnabled,
                _ => ReflEnabled,
            };
            self.table.set(
                id,
                FieldValue::Bool(brush.texture_enabled.get(channel).copied().unwrap_or(true)),
            );
        }
        self.selected = brush.brush_textures.clone();
    }

    fn number(&self, id: TexField) -> f32 {
        match self.table.value(id) {
            FieldValue::Number(n) => n,
            _ => 0.0,
        }
    }

    fn text(&self, id: TexField) -> String {
        match self.table.value(id) {
            FieldValue::Text(t) => t,
            _ => String::new(),
        }
    }

    fn boolean(&self, id: TexField) -> bool {
        matches!(self.table.value(id), FieldValue::Bool(true))
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
        let mut brush = BrushSettings {
            size: self.number(Size),
            rotation: self.number(Rotation),
            ..BrushSettings::default()
        };
        if let FieldValue::Text(pattern) = self.pattern.entry().field.value() {
            brush.pattern_texture = non_empty(pattern);
        }
        self.write_extra(&mut brush);
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
        self.pattern.entry_mut().field.set_value(&FieldValue::Text(
            brush.pattern_texture.clone().unwrap_or_default(),
        ));
        self.table.set(Size, FieldValue::Number(brush.size));
        self.table.set(Rotation, FieldValue::Number(brush.rotation));
        self.table
            .set(TexScale, FieldValue::Number(brush.tex_scale));
        self.table
            .set(TexRotation, FieldValue::Number(brush.tex_rotation));
        self.table
            .set(TexOffsetX, FieldValue::Number(brush.tex_offset_x));
        self.table
            .set(TexOffsetY, FieldValue::Number(brush.tex_offset_y));
        self.table.set(Mode, FieldValue::Text(brush.mode));
        self.table
            .set(KernelMode, FieldValue::Text(brush.kernel_mode));
        self.table.set(Strength, FieldValue::Number(brush.strength));
        self.table
            .set(FalloffFactor, FieldValue::Number(brush.falloff_factor));
        self.table
            .set(FeatureFactor, FieldValue::Number(brush.feature_factor));
        self.table.set(Value, FieldValue::Number(brush.value));
        self.table
            .set(VoidFactor, FieldValue::Number(brush.void_factor));
        self.table
            .set(SplatTexScale, FieldValue::Number(brush.splat_tex_scale));
        self.table
            .set(SplatTexMult, FieldValue::Number(brush.splat_tex_mult));
        self.table.set(Exclusive, FieldValue::Bool(brush.exclusive));
        self.table
            .set(DiffuseColor, FieldValue::Color(brush.diffuse_color));
        self.table.set(
            DntsIndex,
            FieldValue::Number((brush.color_index - 1) as f32),
        );
        for channel in toggle_channels() {
            let id = match channel {
                "diffuse" => DiffuseEnabled,
                "specular" => SpecularEnabled,
                "emission" => EmissionEnabled,
                _ => ReflEnabled,
            };
            self.table.set(
                id,
                FieldValue::Bool(brush.texture_enabled.get(channel).copied().unwrap_or(true)),
            );
        }
        for entry in self.table.fields() {
            let _ = entry.field.write_to_dom(interface);
        }
    }
}

impl EditorModel for TextureUiModel {
    type Id = TexField;

    fn fields(&self) -> Vec<FieldRef<'_>> {
        let mut fields = self.table.fields();
        fields.push(self.pattern.entry());
        fields
    }

    fn fields_mut(&mut self) -> Vec<FieldMut<'_>> {
        let mut fields = self.table.fields_mut();
        fields.push(self.pattern.entry_mut());
        fields
    }

    fn grids(&self) -> Vec<&AssetGrid> {
        vec![&self.pattern]
    }

    fn grids_mut(&mut self) -> Vec<&mut AssetGrid> {
        vec![&mut self.pattern]
    }

    fn id_of(&self, name: &str) -> Option<TexField> {
        if name == "patternTexture" {
            return Some(Pattern);
        }
        self.table.id_of(name)
    }

    fn name_of(&self, id: TexField) -> String {
        if id == Pattern {
            return "patternTexture".to_string();
        }
        self.table.name_of(id)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn normal_is_a_channel_but_has_no_toggle() {
        let toggles: Vec<&str> = toggle_channels().collect();
        assert!(!toggles.contains(&"normal"));
        assert!(toggles.contains(&"diffuse"));
        assert!(CHANNELS.iter().any(|(c, _, _)| *c == "normal"));
    }
}
