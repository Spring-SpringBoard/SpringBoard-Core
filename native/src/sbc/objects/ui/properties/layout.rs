use crate::sbc::panels::runtime::{EditorModel, Item};

use super::model::{PropertiesModel, PropertyLayout};

pub(super) fn layout(model: &PropertiesModel) -> Vec<Item<usize>> {
    if model.selected.is_none() {
        return vec![Item::Custom(
            r#"<div class="field-row"><span class="field-label">No object selected.</span></div>"#
                .to_string(),
        )];
    }
    let id = |name: &str| model.id_of(name);
    let mut items = Vec::new();
    for row in &model.layout {
        match row {
            PropertyLayout::Field(name) => {
                if let Some(id) = id(name) {
                    items.push(Item::Field(id));
                }
            }
            PropertyLayout::Group(names) => {
                items.push(Item::OwnedRow(names.iter().filter_map(|n| id(n)).collect()));
            }
            PropertyLayout::Section(caption) => {
                items.push(Item::OwnedSection(caption.clone()));
            }
        }
    }
    items
}
