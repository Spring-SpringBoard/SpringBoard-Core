use std::cell::RefCell;
use std::collections::BTreeMap;
use std::rc::Rc;

use crate::sbc::panels::controls::grid::GridView;
use crate::sbc::panels::field::FieldValue;
use crate::sbc::panels::fields::{AssetField, BooleanField, NumericField};
use crate::sbc::panels::runtime::{EditorModel, FieldMut, FieldRef, TableEntry, TableModel};
use spring_native::{prelude::Error, RmlDataModel, RmlDataStatusRows, RmlDataVariable};

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub(crate) enum SettingsField {
    VoidWater,
    VoidGround,
    DntsDiffuseAlpha,
    SplatScale0,
    SplatScale1,
    SplatScale2,
    SplatScale3,
    SplatMult0,
    SplatMult1,
    SplatMult2,
    SplatMult3,
    DetailTexture,
    ShadingWidth,
    ShadingHeight,
}

use SettingsField::*;

pub(super) const BOOLEANS: &[SettingsField] = &[VoidWater, VoidGround, DntsDiffuseAlpha];
pub(super) const SPLAT_SCALES: &[SettingsField] =
    &[SplatScale0, SplatScale1, SplatScale2, SplatScale3];
pub(super) const SPLAT_MULTS: &[SettingsField] = &[SplatMult0, SplatMult1, SplatMult2, SplatMult3];
pub(super) const SHADING_TOGGLES: &[(&str, &str, &str)] = &[
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
pub(super) enum ShadingEvent {
    Open(String),
    ShowNew,
    New,
    Existing,
    Disable,
    Cancel,
}

#[derive(Clone, Copy, PartialEq, Eq)]
pub(super) enum ShadingSource {
    New,
    Existing,
}

/// Map rendering flags and the detail texture. Every field is a key of
/// `SetMapRenderingParamsCommand`'s options except `detailTexture`, which the
/// engine takes through its own map-texture binding.
///
/// The command is not undoable (Lua's undo is a stub), so there is nothing to
/// preview: a change applies immediately and stays applied.
pub(crate) struct SettingsModel {
    pub(super) table: TableModel<SettingsField>,
    pub(super) shading_grid: GridView,
    pub(super) shading_events: Rc<RefCell<Vec<ShadingEvent>>>,
    pub(super) shading_enabled: BTreeMap<String, bool>,
    pub(super) dialog: Option<String>,
    pub(super) shading_source: Option<ShadingSource>,
    pub(super) shading_statuses: Option<RmlDataStatusRows<'static>>,
    pub(super) shading_dialog_title: Option<RmlDataVariable<'static, String>>,
    pub(super) shading_dialog_open: Option<RmlDataVariable<'static, bool>>,
    pub(super) shading_source_select_visible: Option<RmlDataVariable<'static, bool>>,
    pub(super) shading_new_form_visible: Option<RmlDataVariable<'static, bool>>,
    pub(super) shading_existing_grid_visible: Option<RmlDataVariable<'static, bool>>,
}

impl SettingsModel {
    pub(crate) fn new() -> Self {
        let splat = |id, name: &'static str, label: &'static str| {
            TableEntry::new(
                id,
                Box::new(NumericField::new(name, label, 1.0).min(0.0).max(1000.0)) as _,
            )
        };
        SettingsModel {
            table: TableModel::new(vec![
                TableEntry::new(
                    VoidWater,
                    Box::new(BooleanField::new("voidWater", "Void water", false)),
                ),
                TableEntry::new(
                    VoidGround,
                    Box::new(BooleanField::new("voidGround", "Void ground", false)),
                ),
                TableEntry::new(
                    DntsDiffuseAlpha,
                    Box::new(BooleanField::new(
                        "splatDetailNormalDiffuseAlpha",
                        "DNTS diffuse alpha",
                        false,
                    )),
                ),
                splat(SplatScale0, "splatTexScale0", "Scale 1"),
                splat(SplatScale1, "splatTexScale1", "Scale 2"),
                splat(SplatScale2, "splatTexScale2", "Scale 3"),
                splat(SplatScale3, "splatTexScale3", "Scale 4"),
                splat(SplatMult0, "splatTexMult0", "Mult 1"),
                splat(SplatMult1, "splatTexMult1", "Mult 2"),
                splat(SplatMult2, "splatTexMult2", "Mult 3"),
                splat(SplatMult3, "splatTexMult3", "Mult 4"),
                TableEntry::new(
                    DetailTexture,
                    // A root *inside* an asset pack, not a VFS path: the picker
                    // walks the packs and lists `assets/<pack>/detail/`.
                    Box::new(
                        AssetField::new("detailTexture", "Detail texture", "detail/")
                            .extensions(&["png", "jpg", "tga", "dds", "bmp"]),
                    ),
                ),
                TableEntry::new(
                    ShadingWidth,
                    Box::new(
                        NumericField::new("shading-width", "Size X", 1024.0)
                            .min(1.0)
                            .step(1.0)
                            .decimals(0),
                    ),
                ),
                TableEntry::new(
                    ShadingHeight,
                    Box::new(
                        NumericField::new("shading-height", "Size Y", 1024.0)
                            .min(1.0)
                            .step(1.0)
                            .decimals(0),
                    ),
                ),
            ]),
            shading_grid: GridView::new("map-shading-texture-grid", 64),
            shading_events: Rc::new(RefCell::new(Vec::new())),
            shading_enabled: BTreeMap::new(),
            dialog: None,
            shading_source: None,
            shading_statuses: None,
            shading_dialog_title: None,
            shading_dialog_open: None,
            shading_source_select_visible: None,
            shading_new_form_visible: None,
            shading_existing_grid_visible: None,
        }
    }

    pub(super) fn splat_values(&self, fields: &[SettingsField]) -> [f32; 4] {
        let number = |id| match self.table.value(id) {
            FieldValue::Number(n) => n,
            _ => 0.0,
        };
        [
            number(fields[0]),
            number(fields[1]),
            number(fields[2]),
            number(fields[3]),
        ]
    }
}

impl EditorModel for SettingsModel {
    type Id = SettingsField;

    fn fields(&self) -> Vec<FieldRef<'_>> {
        self.table.fields()
    }

    fn fields_mut(&mut self) -> Vec<FieldMut<'_>> {
        self.table.fields_mut()
    }

    fn prepare_data_model(&mut self, model: &RmlDataModel<'static>) -> Result<(), Error> {
        self.shading_statuses = Some(model.bind_status_rows("shading_statuses")?);
        self.shading_dialog_title = Some(model.bind("shading_dialog_title", String::new())?);
        self.shading_dialog_open = Some(model.bind("shading_dialog_open", false)?);
        self.shading_source_select_visible =
            Some(model.bind("shading_source_select_visible", false)?);
        self.shading_new_form_visible = Some(model.bind("shading_new_form_visible", false)?);
        self.shading_existing_grid_visible =
            Some(model.bind("shading_existing_grid_visible", false)?);
        Ok(())
    }

    fn id_of(&self, name: &str) -> Option<SettingsField> {
        self.table.id_of(name)
    }

    fn name_of(&self, id: SettingsField) -> String {
        self.table.name_of(id)
    }
}
