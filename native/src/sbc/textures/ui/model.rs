use spring_native::{
    prelude::{Error, NativeInterfaceRef},
    RmlDataModel, RmlDataVariable,
};

use std::cell::RefCell;
use std::collections::BTreeMap;
use std::rc::Rc;

use serde::{Deserialize, Serialize};

use crate::sbc::panels::brush::{non_empty, BrushAction, BrushActions};
use crate::sbc::panels::controls::grid::GridView;
use crate::sbc::panels::field::{Field, FieldValue};
use crate::sbc::panels::fields::StringField;
use crate::sbc::panels::runtime::{AssetGrid, EditorModel, TableModel};
use crate::sbc::panels::tooltip::{TooltipContent, TooltipStatus};
use crate::sbc::project::{EditorState, TextureEditorState};
use crate::sbc::states::BrushSettings;
use crate::sbc::textures::materials::{Material, CHANNELS};

mod editor_model;
mod field_table;

use field_table::{pattern, texture_table};

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

const MATERIAL_CONTROLS_VISIBLE: &str = "texture_material_controls_visible";
const BLUR_CONTROLS_VISIBLE: &str = "texture_blur_controls_visible";
const DNTS_CONTROLS_VISIBLE: &str = "texture_dnts_controls_visible";
const VOID_CONTROLS_VISIBLE: &str = "texture_void_controls_visible";
const STRENGTH_VISIBLE: &str = "texture_strength_visible";
const FALLOFF_VISIBLE: &str = "texture_falloff_visible";
const MATERIAL_PICKER_VISIBLE: &str = "texture_material_picker_visible";

struct TextureVisibility {
    material_controls: RmlDataVariable<'static, bool>,
    blur_controls: RmlDataVariable<'static, bool>,
    dnts_controls: RmlDataVariable<'static, bool>,
    void_controls: RmlDataVariable<'static, bool>,
    strength: RmlDataVariable<'static, bool>,
    falloff: RmlDataVariable<'static, bool>,
    material_picker: RmlDataVariable<'static, bool>,
}

impl TextureVisibility {
    fn bind(model: &RmlDataModel<'static>) -> Result<Self, Error> {
        Ok(Self {
            material_controls: model.bind(MATERIAL_CONTROLS_VISIBLE, true)?,
            blur_controls: model.bind(BLUR_CONTROLS_VISIBLE, false)?,
            dnts_controls: model.bind(DNTS_CONTROLS_VISIBLE, false)?,
            void_controls: model.bind(VOID_CONTROLS_VISIBLE, false)?,
            strength: model.bind(STRENGTH_VISIBLE, true)?,
            falloff: model.bind(FALLOFF_VISIBLE, true)?,
            material_picker: model.bind(MATERIAL_PICKER_VISIBLE, false)?,
        })
    }

    fn sync(&self, mode: &str, material_picker_open: bool) {
        let material = mode == "paint";
        let _ = self.material_controls.set(material);
        let _ = self.blur_controls.set(mode == "blur");
        let _ = self.dnts_controls.set(mode == "dnts");
        let _ = self.void_controls.set(mode == "void");
        let _ = self.strength.set(mode != "void");
        let _ = self.falloff.set(mode != "blur");
        let _ = self.material_picker.set(material && material_picker_open);
    }
}

pub(super) fn material_tooltip(material: &Material) -> TooltipContent {
    TooltipContent::statuses(
        material.name.clone(),
        [
            ("diffuse", "Diffuse"),
            ("normal", "Normal"),
            ("specular", "Specular"),
        ]
        .into_iter()
        .map(|(channel, label)| TooltipStatus {
            label: label.to_owned(),
            positive: material.channels.contains_key(channel),
        })
        .collect(),
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
    /// Control-only material selector; it is not rendered as a panel row.
    Material,
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

/// The texture brush: a pattern, a material, and how it is blended in.
pub(crate) struct TextureUiModel {
    pub(super) table: TableModel<TexField>,
    pub(super) actions: BrushActions,
    pattern: AssetGrid,
    pub(super) material: StringField,
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
    material_control_changed: bool,
    /// Which DNTS channels the map actually has. Lua disables the button when
    /// there are none.
    pub(super) dnts_available: Vec<i32>,
    visibility: Option<TextureVisibility>,
}

impl TextureUiModel {
    pub(crate) fn new() -> Self {
        TextureUiModel {
            table: texture_table(),
            actions: BrushActions::new(ACTIONS),
            pattern: AssetGrid::of(pattern()),
            material: StringField::new("material", "Material", ""),
            saved_brush_grid: GridView::new("texture-saved-brush-grid", 64),
            material_grid: GridView::new("texture-material-grid", 64),
            materials: Vec::new(),
            selected_material: None,
            selected: BTreeMap::new(),
            saved_brushes: Vec::new(),
            selected_brush: None,
            material_picker_open: false,
            material_picker_events: Rc::new(RefCell::new(Vec::new())),
            material_control_changed: false,
            dnts_available: Vec::new(),
            visibility: None,
        }
    }

    /// The current paint mode, which decides both what is painted and which
    /// fields are meaningful (Lua's `SetInvisibleFields` per action button).
    pub(super) fn paint_mode(&self) -> &str {
        self.actions.selected_paint_mode().unwrap_or("paint")
    }

    pub(super) fn sync_visibility(&self) {
        self.visibility
            .as_ref()
            .expect("texture visibility bindings are prepared before editor markup")
            .sync(self.paint_mode(), self.material_picker_open);
    }

    pub(super) fn field_visibility_binding(&self, id: TexField) -> Option<&'static str> {
        match id {
            Mode | TexScale | TexRotation | TexOffsetX | TexOffsetY | FeatureFactor
            | DiffuseColor | DiffuseEnabled | SpecularEnabled | EmissionEnabled | ReflEnabled => {
                Some(MATERIAL_CONTROLS_VISIBLE)
            }
            KernelMode => Some(BLUR_CONTROLS_VISIBLE),
            SplatTexScale | SplatTexMult | Value | DntsIndex | Exclusive => {
                Some(DNTS_CONTROLS_VISIBLE)
            }
            VoidFactor => Some(VOID_CONTROLS_VISIBLE),
            Strength => Some(STRENGTH_VISIBLE),
            FalloffFactor => Some(FALLOFF_VISIBLE),
            Pattern | Size | Rotation => None,
            Material => Some(MATERIAL_CONTROLS_VISIBLE),
        }
    }

    pub(super) fn material_dialog_rml(&self) -> String {
        format!(
            r#"<div class="picker-backdrop" data-model="editor_fields" data-class-hidden="!{MATERIAL_PICKER_VISIBLE}">
                <div class="dialog picker-dialog asset-dialog">
                    <div class="dialog-header"><span class="dialog-title">Select material for new brush</span></div>
                    <div class="dialog-content">{}</div>
                    <div class="dialog-footer"><button id="texture-material-cancel" class="dialog-button">Cancel</button></div>
                </div>
            </div>"#,
            self.material_grid.container_rml(),
        )
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
        self.material.set_value(&FieldValue::Text(
            self.selected_material.clone().unwrap_or_default(),
        ));
    }

    pub(super) fn save_editor_state(&self, state: &mut EditorState) {
        state.set_texture(TextureEditorState {
            saved_brushes: self.saved_brushes.clone(),
            selected_brush: self.selected_brush.clone(),
            selected_material: self.selected_material.clone(),
        });
    }

    /// Select a material through the typed editor surface and create the same
    /// saved brush as the visible material picker.
    pub(super) fn select_material_control(
        &mut self,
        name: &str,
        interface: &NativeInterfaceRef,
    ) -> bool {
        if self.materials.is_empty() {
            self.materials = crate::sbc::textures::materials::list_materials(interface);
        }
        let Some(material) = self.materials.iter().find(|material| material.name == name) else {
            return false;
        };
        self.selected = material.channels.clone();
        self.selected_material = Some(material.name.clone());
        self.create_saved_brush(material.name.clone());
        self.material_picker_open = false;
        self.material_control_changed = true;
        self.sync_visibility();
        true
    }

    pub(super) fn take_material_control_changed(&mut self) -> bool {
        std::mem::take(&mut self.material_control_changed)
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
