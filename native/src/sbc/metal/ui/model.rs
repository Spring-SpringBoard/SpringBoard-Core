use crate::sbc::panels::runtime::{
    AssetGrid, AssetGridDef, Brush, EditorModel, FieldMut, FieldRef, Num, NumDef,
};

static PATTERN: AssetGridDef = AssetGridDef {
    name: "patternTexture",
    container: "metal-pattern-grid",
    root: "brush_patterns/terrain/",
    extensions: &["png", "jpg", "tga", "dds", "bmp"],
    cell: 64,
    brush: Some(Brush::Pattern),
};

static SIZE: NumDef = NumDef {
    name: "size",
    label: "Size",
    default: 100.0,
    min: Some(10.0),
    max: Some(5000.0),
    brush: Some(Brush::Size),
    ..NumDef::BASE
}
.checked();

static ROTATION: NumDef = NumDef {
    name: "rotation",
    label: "Rotation",
    default: 0.0,
    min: Some(-360.0),
    max: Some(360.0),
    brush: Some(Brush::Rotation),
    ..NumDef::BASE
}
.checked();

static AMOUNT: NumDef = NumDef {
    name: "amount",
    label: "Amount",
    default: 50.0,
    min: Some(0.0),
    max: Some(5.1),
    decimals: Some(2),
    brush: Some(Brush::Amount),
    ..NumDef::BASE
};

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub(crate) enum MetalField {
    Pattern,
    Size,
    Rotation,
    Amount,
}

/// The metal brush.
pub(crate) struct MetalModel {
    pattern: AssetGrid,
    size: Num,
    rotation: Num,
    amount: Num,
}

impl Default for MetalModel {
    fn default() -> Self {
        MetalModel {
            pattern: AssetGrid::of(&PATTERN),
            size: Num::of(&SIZE),
            rotation: Num::of(&ROTATION),
            amount: Num::of(&AMOUNT),
        }
    }
}

impl EditorModel for MetalModel {
    type Id = MetalField;

    fn fields(&self) -> Vec<FieldRef<'_>> {
        vec![
            self.pattern.entry(),
            self.size.entry(),
            self.rotation.entry(),
            self.amount.entry(),
        ]
    }

    fn fields_mut(&mut self) -> Vec<FieldMut<'_>> {
        vec![
            self.pattern.entry_mut(),
            self.size.entry_mut(),
            self.rotation.entry_mut(),
            self.amount.entry_mut(),
        ]
    }

    fn grids(&self) -> Vec<&AssetGrid> {
        vec![&self.pattern]
    }

    fn grids_mut(&mut self) -> Vec<&mut AssetGrid> {
        vec![&mut self.pattern]
    }

    fn id_of(&self, name: &str) -> Option<MetalField> {
        match name {
            "patternTexture" => Some(MetalField::Pattern),
            "size" => Some(MetalField::Size),
            "rotation" => Some(MetalField::Rotation),
            "amount" => Some(MetalField::Amount),
            _ => None,
        }
    }

    fn name_of(&self, id: MetalField) -> String {
        match id {
            MetalField::Pattern => "patternTexture",
            MetalField::Size => "size",
            MetalField::Rotation => "rotation",
            MetalField::Amount => "amount",
        }
        .to_string()
    }
}
