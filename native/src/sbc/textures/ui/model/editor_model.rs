use super::{TexField, TextureUiModel};
use spring_native::{prelude::Error, RmlDataModel};

use crate::sbc::panels::runtime::{AssetGrid, EditorModel, FieldMut, FieldRef};
use crate::sbc::panels::tooltip::PanelTooltip;

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

    fn set_tooltip_host(&mut self, tooltip: PanelTooltip) {
        self.actions.set_tooltip_host(tooltip);
    }

    fn prepare_data_model(&mut self, model: &RmlDataModel<'static>) -> Result<(), Error> {
        self.actions.prepare_data_model(model)?;
        self.visibility = Some(super::TextureVisibility::bind(model)?);
        Ok(())
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

    fn field_visibility_binding(&self, id: TexField) -> Option<&'static str> {
        self.field_visibility_binding(id)
    }
}
