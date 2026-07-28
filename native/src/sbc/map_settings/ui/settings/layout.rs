use spring_native::prelude::{Error, NativeInterfaceRef};

use crate::sbc::panels::controls::grid::{list_assets, GridItem};
use crate::sbc::panels::editor_base::group_rml;
use crate::sbc::panels::runtime::Item;

use super::model::SettingsField::*;
use super::model::{SettingsField, SettingsModel, ShadingSource, SHADING_TOGGLES};

pub(super) fn layout(model: &SettingsModel) -> Vec<Item<SettingsField>> {
    vec![
        Item::Section("Map textures"),
        Item::Field(DetailTexture),
        Item::Custom(model.shading_markup()),
        Item::Section("Terrain visibility"),
        // A switch button needs room for its label, track and clear state;
        // stack these rather than squeezing two into checkbox-sized cells.
        Item::Field(VoidWater),
        Item::Field(VoidGround),
        Item::Field(DntsDiffuseAlpha),
        Item::Section("Splat mapping"),
        // Four label/value controls across 500dp leave the values clipped.
        // Two even columns retain a comfortable numeric editing target.
        Item::Row(&[SplatScale0, SplatScale1]),
        Item::Row(&[SplatScale2, SplatScale3]),
        Item::Row(&[SplatMult0, SplatMult1]),
        Item::Row(&[SplatMult2, SplatMult3]),
    ]
}

impl SettingsModel {
    pub(super) fn shading_markup(&self) -> String {
        r#"<div id="shading-texture-actions">
            <div data-for="shading : shading_statuses" data-if="shading.visible" class="field-row">
                <button class="field-composite-button shading-texture-button">
                    <span>{{ shading.label }}</span>
                    <span data-class-shading-enabled="shading.positive" data-class-shading-disabled="!shading.positive">
                        <span data-if="shading.positive">enabled</span>
                        <span data-if="!shading.positive">not set</span>
                    </span>
                </button>
            </div>
        </div>"#
            .to_owned()
    }

    pub(super) fn dialog_markup(&self) -> String {
        let dimensions = group_rml(&[
            self.table.field_rml(ShadingWidth),
            self.table.field_rml(ShadingHeight),
        ]);
        format!(
            r#"<div id="shading-texture-dialog" class="picker-backdrop" data-model="editor_fields" data-class-hidden="!shading_dialog_open">
                <div class="dialog picker-dialog asset-dialog">
                    <div class="dialog-header"><span id="shading-dialog-title" class="dialog-title">{{ shading_dialog_title }}</span></div>
                    <div class="dialog-content">
                        <div id="shading-source-choice" class="shading-dialog-actions" data-class-hidden="!shading_source_select_visible">
                            <button id="shading-new" class="dialog-button primary">New texture</button>
                            <button id="shading-existing" class="dialog-button">Choose existing</button>
                            <button id="shading-disable" class="dialog-button">Disable</button>
                        </div>
                        <div id="shading-new-form" data-class-hidden="!shading_new_form_visible">
                            {dimensions}
                            <div class="dialog-hint">Creates a blank texture using this channel's sensible default colour.</div>
                            <div class="field-row"><button id="shading-create" class="dialog-button primary">Create texture</button></div>
                        </div>
                        <div id="shading-existing-grid" data-class-hidden="!shading_existing_grid_visible">{}</div>
                    </div>
                    <div class="dialog-footer"><button id="shading-cancel" class="dialog-button">Cancel</button></div>
                </div>
            </div>"#,
            self.shading_grid.container_rml(),
            dimensions = dimensions,
        )
    }

    pub(super) fn render_shading_fields(&mut self) {
        if let Some(rows) = &self.shading_statuses {
            let statuses = SHADING_TOGGLES
                .iter()
                .map(|(field, _, caption)| spring_native::RmlStatusRow {
                    label: (*caption).to_owned(),
                    positive: self.shading_enabled.get(*field).copied().unwrap_or(false),
                })
                .collect::<Vec<_>>();
            let _ = rows.set(&statuses);
        }
    }

    pub(super) fn render_dialog(&self) {
        let open = self.dialog.is_some();
        let _ = self
            .shading_dialog_open
            .as_ref()
            .expect("shading dialog bindings are prepared before its markup")
            .set(open);
        if let Some(name) = &self.dialog {
            if let Some(title) = &self.shading_dialog_title {
                let caption = SHADING_TOGGLES
                    .iter()
                    .find(|(_, shading, _)| shading == name)
                    .map(|(_, _, caption)| *caption)
                    .unwrap_or(name.as_str());
                let _ = title.set(format!("{caption} texture"));
            }
        }
        let source = self.shading_source;
        let _ = self
            .shading_source_select_visible
            .as_ref()
            .expect("shading dialog bindings are prepared before its markup")
            .set(open && source.is_none());
        let _ = self
            .shading_new_form_visible
            .as_ref()
            .expect("shading dialog bindings are prepared before its markup")
            .set(open && source == Some(ShadingSource::New));
        let _ = self
            .shading_existing_grid_visible
            .as_ref()
            .expect("shading dialog bindings are prepared before its markup")
            .set(open && source == Some(ShadingSource::Existing));
    }

    pub(super) fn render_existing_grid(
        &mut self,
        interface: &NativeInterfaceRef,
        document: u64,
    ) -> Result<(), Error> {
        let items = list_assets(
            interface,
            "springboard/assets/core/detail",
            &[".png", ".jpg", ".tga", ".dds", ".bmp"],
        )
        .into_iter()
        .map(|mut item| {
            item.tooltip = Some("Choose this existing texture".to_string());
            item
        })
        .collect::<Vec<GridItem>>();
        self.shading_grid.set_items(items);
        self.shading_grid.render(interface, document)
    }
}
