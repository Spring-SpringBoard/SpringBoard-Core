use crate::sbc::panels::runtime::{
    AssetGrid, AssetGridDef, Brush, Choice, ChoiceDef, EditorModel, FieldMut, FieldRef, Num,
    NumDef, Options,
};
use crate::sbc::states::ApplyDir;

static PATTERN: AssetGridDef = AssetGridDef {
    name: "patternTexture",
    container: "terrain-pattern-grid",
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

static STRENGTH: NumDef = NumDef {
    name: "strength",
    label: "Strength",
    default: 10.0,
    step: Some(0.1),
    decimals: Some(1),
    brush: Some(Brush::Strength),
    ..NumDef::BASE
}
.checked();

static HEIGHT: NumDef = NumDef {
    name: "height",
    label: "Height",
    default: 10.0,
    step: Some(0.1),
    decimals: Some(1),
    brush: Some(Brush::Height),
    ..NumDef::BASE
}
.checked();

static APPLY_DIR: ChoiceDef<ApplyDir> = ChoiceDef {
    name: "applyDir",
    label: "Direction",
    default: ApplyDir::Both,
    brush: Some(Brush::ApplyDirection),
};

impl Options for ApplyDir {
    const ALL: &'static [ApplyDir] = &[ApplyDir::Both, ApplyDir::OnlyRaise, ApplyDir::OnlyLower];

    fn label(self) -> &'static str {
        match self {
            ApplyDir::Both => "Both",
            ApplyDir::OnlyRaise => "Only Raise",
            ApplyDir::OnlyLower => "Only Lower",
        }
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub(crate) enum TerrainField {
    Pattern,
    Size,
    Rotation,
    Strength,
    Height,
    ApplyDir,
}

/// The height brush: shape pattern, size, rotation and how hard it pushes.
pub(crate) struct TerrainModel {
    pattern: AssetGrid,
    size: Num,
    rotation: Num,
    strength: Num,
    height: Num,
    apply_dir: Choice<ApplyDir>,
}

impl Default for TerrainModel {
    fn default() -> Self {
        TerrainModel {
            pattern: AssetGrid::of(&PATTERN),
            size: Num::of(&SIZE),
            rotation: Num::of(&ROTATION),
            strength: Num::of(&STRENGTH),
            height: Num::of(&HEIGHT),
            apply_dir: Choice::of(&APPLY_DIR),
        }
    }
}

impl EditorModel for TerrainModel {
    type Id = TerrainField;

    fn fields(&self) -> Vec<FieldRef<'_>> {
        vec![
            self.pattern.entry(),
            self.size.entry(),
            self.rotation.entry(),
            self.strength.entry(),
            self.height.entry(),
            self.apply_dir.entry(),
        ]
    }

    fn fields_mut(&mut self) -> Vec<FieldMut<'_>> {
        vec![
            self.pattern.entry_mut(),
            self.size.entry_mut(),
            self.rotation.entry_mut(),
            self.strength.entry_mut(),
            self.height.entry_mut(),
            self.apply_dir.entry_mut(),
        ]
    }

    fn grids(&self) -> Vec<&AssetGrid> {
        vec![&self.pattern]
    }

    fn grids_mut(&mut self) -> Vec<&mut AssetGrid> {
        vec![&mut self.pattern]
    }

    fn id_of(&self, name: &str) -> Option<TerrainField> {
        match name {
            "patternTexture" => Some(TerrainField::Pattern),
            "size" => Some(TerrainField::Size),
            "rotation" => Some(TerrainField::Rotation),
            "strength" => Some(TerrainField::Strength),
            "height" => Some(TerrainField::Height),
            "applyDir" => Some(TerrainField::ApplyDir),
            _ => None,
        }
    }

    fn name_of(&self, id: TerrainField) -> String {
        match id {
            TerrainField::Pattern => "patternTexture",
            TerrainField::Size => "size",
            TerrainField::Rotation => "rotation",
            TerrainField::Strength => "strength",
            TerrainField::Height => "height",
            TerrainField::ApplyDir => "applyDir",
        }
        .to_string()
    }
}
