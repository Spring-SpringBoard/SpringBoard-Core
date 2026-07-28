use crate::sbc::panels::runtime::Item;

use super::model::{DefKind, ObjectDefsModel, ObjectField, PlaceMode};

const ROT_X: &[ObjectField] = &[ObjectField::RotXMin, ObjectField::RotXMax];
const ROT_Y: &[ObjectField] = &[ObjectField::RotYMin, ObjectField::RotYMax];
const ROT_Z: &[ObjectField] = &[ObjectField::RotZMin, ObjectField::RotZMax];
const UNIT_FILTERS: &[ObjectField] = &[ObjectField::TypeFilter, ObjectField::TerrainFilter];
const FEATURE_FILTERS: &[ObjectField] = &[ObjectField::TypeFilter, ObjectField::WreckFilter];

pub(super) fn layout(model: &ObjectDefsModel) -> Vec<Item<ObjectField>> {
    let mut items = vec![
        Item::Custom(model.mode_buttons_rml()),
        Item::Section("Definitions"),
    ];
    // The filters over the grid, as in Lua's MakeFilters: Units get Type +
    // Terrain, Features get Type + Wreck + Terrain.
    match model.kind {
        DefKind::Unit => items.push(Item::Row(UNIT_FILTERS)),
        DefKind::Feature => {
            items.push(Item::Row(FEATURE_FILTERS));
            items.push(Item::Field(ObjectField::TerrainFilter));
        }
    }
    // The definitions come first -- filters, search, then the grid -- and
    // the placement settings sit *below* it, as they do in the Lua UI.
    items.push(Item::Custom(model.search_and_grid_rml()));
    items.push(Item::Field(ObjectField::Team));
    // Only the active mode's fields.
    match model.mode {
        PlaceMode::Set => items.push(Item::Field(ObjectField::Amount)),
        PlaceMode::Brush => {
            items.push(Item::Field(ObjectField::Size));
            items.push(Item::Field(ObjectField::Spread));
            items.push(Item::Field(ObjectField::Noise));
            items.push(Item::Row(ROT_X));
            items.push(Item::Row(ROT_Y));
            items.push(Item::Row(ROT_Z));
        }
    }
    items
}

impl ObjectDefsModel {
    pub(super) fn mode_buttons_rml(&self) -> String {
        r#"<div id="objectdef-mode-actions" class="brush-actions">
            <button data-for="action : objectdef_mode_actions" data-if="action.visible" class="brush-action" data-class-pressed="action.pressed" data-class-disabled="action.disabled">
                <img data-attr-src="action.icon" class="brush-action-icon"/>
                <span class="brush-action-label">{{ action.label }}</span>
            </button>
        </div>"#
            .to_owned()
    }

    pub(super) fn search_and_grid_rml(&self) -> String {
        format!(
            concat!(
                r#"<div class="field-row">"#,
                r#"<span class="field-label">Search:</span>"#,
                r#"<input type="text" id="object-defs-search" class="field-input"/>"#,
                r#"</div>{grid}"#,
            ),
            grid = self.grid.container_rml(),
        )
    }
}
