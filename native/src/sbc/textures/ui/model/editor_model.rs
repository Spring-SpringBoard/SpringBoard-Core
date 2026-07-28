use super::{TexField, TextureUiModel};
use crate::sbc::panels::runtime::{AssetGrid, EditorModel, FieldMut, FieldRef};

use TexField::*;

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
