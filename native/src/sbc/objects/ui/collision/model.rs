use std::cell::RefCell;
use std::rc::Rc;

use spring_native::{RmlDataModel, RmlDataVariable};

use crate::sbc::objects::ObjectKind;
use crate::sbc::panels::field::FieldValue;
use crate::sbc::panels::fields::{BooleanField, ChoiceField, NumericField};
use crate::sbc::panels::runtime::{EditorModel, FieldMut, FieldRef, TableEntry, TableModel};

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub(crate) enum ColField {
    VType,
    Axis,
    ScaleX,
    ScaleY,
    ScaleZ,
    OffsetX,
    OffsetY,
    OffsetZ,
    Radius,
    Height,
    MpX,
    MpY,
    MpZ,
    ApX,
    ApY,
    ApZ,
    IsBlocking,
    IsSolidObjectCollidable,
    IsProjectileCollidable,
    IsRaySegmentCollidable,
    Crushable,
    BlockEnemyPushing,
    BlockHeightChanges,
}

use ColField::*;

pub(super) const SCALES: &[ColField] = &[ScaleX, ScaleY, ScaleZ];
pub(super) const COLLISION_FIELDS: &[ColField] = &[
    ScaleX, ScaleY, ScaleZ, OffsetX, OffsetY, OffsetZ, VType, Axis,
];
pub(super) const MID_AIM_FIELDS: &[ColField] = &[MpX, MpY, MpZ, ApX, ApY, ApZ];
pub(super) const BLOCKING_FIELDS: &[ColField] = &[
    IsBlocking,
    IsSolidObjectCollidable,
    IsProjectileCollidable,
    IsRaySegmentCollidable,
    Crushable,
    BlockEnemyPushing,
    BlockHeightChanges,
];

/// Collision volume editor for the selected unit or feature.
///
/// Ports `scen_edit/view/object/collision_window.lua`. The engine stores four
/// composite objects — `collision` (scale/offset/type/axis), `radiusHeight`,
/// `midAimPos`, and `blocking` — which this editor decomposes into individual
/// fields and re-bundles on change.
///
/// Cross-field coupling (faithful to the Lua original):
/// - **Sphere** syncs all three scales and hides scale Y/Z + axis.
/// - **Cylinder** links two scales based on the chosen axis.
/// - **Box** hides the axis field.
pub(crate) struct CollisionModel {
    pub(super) table: TableModel<ColField>,
    pub(super) selected: Option<(ObjectKind, i32)>,
    pub(super) selection_revision: u64,
    /// Engine-side testType; not user-editable, but must be preserved in writes.
    pub(super) test_type: i32,
    pub(super) show_vol_clicked: Rc<RefCell<bool>>,
    axis_visible: Option<RmlDataVariable<'static, bool>>,
    sphere_scales_visible: Option<RmlDataVariable<'static, bool>>,
}

impl CollisionModel {
    pub(crate) fn new() -> Self {
        let compact =
            |id, name: &'static str, label: &'static str, default: f32, min: Option<f32>| {
                let mut field = NumericField::new(name, label, default)
                    .decimals(0)
                    .step(1.0)
                    .compact();
                if let Some(min) = min {
                    field = field.min(min);
                }
                TableEntry::new(id, Box::new(field) as _)
            };
        let toggle = |id, name: &'static str, label: &'static str| {
            TableEntry::new(id, Box::new(BooleanField::new(name, label, true)) as _)
        };
        CollisionModel {
            table: TableModel::new(vec![
                TableEntry::new(
                    VType,
                    Box::new(ChoiceField::new(
                        "vType",
                        "Type",
                        vec![
                            "Cylinder".to_string(),
                            "Box".to_string(),
                            "Sphere".to_string(),
                        ],
                    )),
                ),
                TableEntry::new(
                    Axis,
                    Box::new(ChoiceField::new(
                        "axis",
                        "Axis",
                        vec!["X".to_string(), "Y".to_string(), "Z".to_string()],
                    )),
                ),
                compact(ScaleX, "scaleX", "X", 1.0, Some(0.0)),
                compact(ScaleY, "scaleY", "Y", 1.0, Some(0.0)),
                compact(ScaleZ, "scaleZ", "Z", 1.0, Some(0.0)),
                compact(OffsetX, "offsetX", "X", 0.0, None),
                compact(OffsetY, "offsetY", "Y", 0.0, None),
                compact(OffsetZ, "offsetZ", "Z", 0.0, None),
                TableEntry::new(
                    Radius,
                    Box::new(
                        NumericField::new("radius", "Radius", 0.0)
                            .decimals(0)
                            .step(1.0)
                            .min(0.0),
                    ),
                ),
                TableEntry::new(
                    Height,
                    Box::new(
                        NumericField::new("height", "Height", 0.0)
                            .decimals(0)
                            .step(1.0)
                            .min(0.0)
                            .max(256.0),
                    ),
                ),
                compact(MpX, "mpx", "X", 0.0, None),
                compact(MpY, "mpy", "Y", 0.0, None),
                compact(MpZ, "mpz", "Z", 0.0, None),
                compact(ApX, "apx", "X", 0.0, None),
                compact(ApY, "apy", "Y", 0.0, None),
                compact(ApZ, "apz", "Z", 0.0, None),
                toggle(IsBlocking, "isBlocking", "Blocking"),
                toggle(
                    IsSolidObjectCollidable,
                    "isSolidObjectCollidable",
                    "Solid object collidable",
                ),
                toggle(
                    IsProjectileCollidable,
                    "isProjectileCollidable",
                    "Projectile collidable",
                ),
                toggle(
                    IsRaySegmentCollidable,
                    "isRaySegmentCollidable",
                    "Ray segment collidable",
                ),
                toggle(Crushable, "crushable", "Crushable"),
                toggle(
                    BlockEnemyPushing,
                    "blockEnemyPushing",
                    "Block enemy pushing",
                ),
                toggle(
                    BlockHeightChanges,
                    "blockHeightChanges",
                    "Block height changes",
                ),
            ]),
            selected: None,
            selection_revision: u64::MAX,
            test_type: 1,
            show_vol_clicked: Rc::new(RefCell::new(false)),
            axis_visible: None,
            sphere_scales_visible: None,
        }
    }

    pub(super) fn number(&self, id: ColField) -> f32 {
        match self.table.value(id) {
            FieldValue::Number(n) => n,
            _ => 0.0,
        }
    }

    pub(super) fn text(&self, id: ColField) -> String {
        match self.table.value(id) {
            FieldValue::Text(t) => t,
            _ => String::new(),
        }
    }

    pub(super) fn boolean(&self, id: ColField) -> bool {
        matches!(self.table.value(id), FieldValue::Bool(true))
    }

    pub(super) fn sync_visibility(&self) {
        let Some(axis_visible) = &self.axis_visible else {
            return;
        };
        let vtype = self.text(VType);
        let _ = axis_visible.set(!matches!(vtype.as_str(), "Sphere" | "Box"));
        if let Some(scales_visible) = &self.sphere_scales_visible {
            let _ = scales_visible.set(vtype != "Sphere");
        }
    }

    /// Sync linked scale fields when vType is Sphere or Cylinder, mirroring the
    /// Lua `OnFieldChange` coupling logic.
    pub(super) fn sync_linked_scales(&mut self, id: ColField) {
        if !SCALES.contains(&id) {
            return;
        }
        let vtype = self.text(VType);
        let value = self.number(id);

        if vtype == "Sphere" {
            for scale in SCALES {
                self.table.set(*scale, FieldValue::Number(value));
            }
        } else if vtype == "Cylinder" {
            let axis = self.text(Axis);
            let linked = match (axis.as_str(), id) {
                ("X", ScaleX) => Some(ScaleZ),
                ("X", ScaleZ) => Some(ScaleX),
                ("Y", ScaleX) => Some(ScaleY),
                ("Y", ScaleY) => Some(ScaleX),
                ("Z", ScaleY) => Some(ScaleZ),
                ("Z", ScaleZ) => Some(ScaleY),
                _ => None,
            };
            if let Some(other) = linked {
                self.table.set(other, FieldValue::Number(value));
            }
        }
    }
}

impl EditorModel for CollisionModel {
    type Id = ColField;

    fn fields(&self) -> Vec<FieldRef<'_>> {
        self.table.fields()
    }

    fn fields_mut(&mut self) -> Vec<FieldMut<'_>> {
        self.table.fields_mut()
    }

    fn prepare_data_model(
        &mut self,
        model: &RmlDataModel<'static>,
    ) -> Result<(), spring_native::prelude::Error> {
        self.axis_visible = Some(model.bind("collision_axis_visible", true)?);
        self.sphere_scales_visible = Some(model.bind("collision_sphere_scales_visible", true)?);
        self.sync_visibility();
        Ok(())
    }

    fn id_of(&self, name: &str) -> Option<ColField> {
        self.table.id_of(name)
    }

    fn name_of(&self, id: ColField) -> String {
        self.table.name_of(id)
    }

    fn field_visibility_binding(&self, id: ColField) -> Option<&'static str> {
        match id {
            Axis => Some("collision_axis_visible"),
            ScaleY | ScaleZ => Some("collision_sphere_scales_visible"),
            _ => None,
        }
    }
}
