use crate::sbc::panels::runtime::{
    AssetGrid, AssetGridDef, Brush, EditorModel, FieldMut, FieldRef, Num, NumDef,
};

static PATTERN: AssetGridDef = AssetGridDef {
    name: "patternTexture",
    container: "grass-pattern-grid",
    root: "brush_patterns/terrain/",
    extensions: &["png", "jpg", "tga", "dds", "bmp"],
    cell: 64,
    brush: Some(Brush::Pattern),
};

static GRASS_DETAIL: NumDef = NumDef {
    name: "grassDetail",
    label: "Detail",
    default: 5.0,
    min: Some(0.0),
    max: Some(10.0),
    ..NumDef::BASE
}
.checked();

static SIZE: NumDef = NumDef {
    name: "size",
    label: "Size",
    default: 100.0,
    min: Some(40.0),
    max: Some(2000.0),
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

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub(crate) enum GrassField {
    Pattern,
    Detail,
    Size,
    Rotation,
}

/// The grass brush. `grassDetail` is an engine config value rather than brush
/// state, so it is applied straight away, as Lua does with `SetConfigInt`.
pub(crate) struct GrassModel {
    pub(super) pattern: AssetGrid,
    pub(super) detail: Num,
    pub(super) size: Num,
    pub(super) rotation: Num,
}

impl Default for GrassModel {
    fn default() -> Self {
        GrassModel {
            pattern: AssetGrid::of(&PATTERN),
            detail: Num::of(&GRASS_DETAIL),
            size: Num::of(&SIZE),
            rotation: Num::of(&ROTATION),
        }
    }
}

impl EditorModel for GrassModel {
    type Id = GrassField;

    fn fields(&self) -> Vec<FieldRef<'_>> {
        vec![
            self.pattern.entry(),
            self.detail.entry(),
            self.size.entry(),
            self.rotation.entry(),
        ]
    }

    fn fields_mut(&mut self) -> Vec<FieldMut<'_>> {
        vec![
            self.pattern.entry_mut(),
            self.detail.entry_mut(),
            self.size.entry_mut(),
            self.rotation.entry_mut(),
        ]
    }

    fn grids(&self) -> Vec<&AssetGrid> {
        vec![&self.pattern]
    }

    fn grids_mut(&mut self) -> Vec<&mut AssetGrid> {
        vec![&mut self.pattern]
    }

    fn id_of(&self, name: &str) -> Option<GrassField> {
        match name {
            "patternTexture" => Some(GrassField::Pattern),
            "grassDetail" => Some(GrassField::Detail),
            "size" => Some(GrassField::Size),
            "rotation" => Some(GrassField::Rotation),
            _ => None,
        }
    }

    fn name_of(&self, id: GrassField) -> String {
        match id {
            GrassField::Pattern => "patternTexture",
            GrassField::Detail => "grassDetail",
            GrassField::Size => "size",
            GrassField::Rotation => "rotation",
        }
        .to_string()
    }
}
