use spring_native::prelude::{Error, NativeInterfaceRef};

use crate::sbc::panels::controls::grid::{list_assets, GridItem};
use crate::sbc::panels::runtime::Item;
use crate::sbc::rml::{element_by_id, escape_rml};

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
        let mut html = String::new();
        for (field, _, caption) in SHADING_TOGGLES {
            html.push_str(&format!(
                r#"<div class="field-row"><button id="shading-{field}" class="field-composite-button shading-texture-button"><span>{caption}</span><span id="shading-status-{field}"></span></button></div>"#,
                field = escape_rml(field),
                caption = escape_rml(caption),
            ));
        }
        html
    }

    pub(super) fn dialog_markup(&self) -> String {
        format!(
            r#"<div id="shading-texture-dialog" class="picker-backdrop hidden">
                <div class="dialog picker-dialog asset-dialog">
                    <div class="dialog-header"><span id="shading-dialog-title" class="dialog-title">Map texture</span></div>
                    <div class="dialog-content">
                        <div id="shading-source-choice" class="shading-dialog-actions">
                            <button id="shading-new" class="dialog-button primary">New texture</button>
                            <button id="shading-existing" class="dialog-button">Choose existing</button>
                            <button id="shading-disable" class="dialog-button">Disable</button>
                        </div>
                        <div id="shading-new-form" class="hidden">
                            <div class="field-row"><label class="field-label">Width:</label><input id="shading-width" class="field-input" value="1024"/></div>
                            <div class="field-row"><label class="field-label">Height:</label><input id="shading-height" class="field-input" value="1024"/></div>
                            <div class="dialog-hint">Creates a blank texture using this channel's sensible default colour.</div>
                            <div class="field-row"><button id="shading-create" class="dialog-button primary">Create texture</button></div>
                        </div>
                        <div id="shading-existing-grid" class="hidden">{}</div>
                    </div>
                    <div class="dialog-footer"><button id="shading-cancel" class="dialog-button">Cancel</button></div>
                </div>
            </div>"#,
            self.shading_grid.container_rml()
        )
    }

    pub(super) fn render_shading_fields(&self, interface: &NativeInterfaceRef, document: u64) {
        for (field, _, caption) in SHADING_TOGGLES {
            let Some(button) = element_by_id(interface, document, &format!("shading-{field}"))
            else {
                continue;
            };
            let enabled = self.shading_enabled.get(*field).copied().unwrap_or(false);
            let status = if enabled {
                "<span class=\"shading-enabled\">enabled</span>"
            } else {
                "<span class=\"shading-disabled\">not set</span>"
            };
            let markup = format!(
                "<span>{}</span><span id=\"shading-status-{}\">{}</span>",
                escape_rml(caption),
                escape_rml(field),
                status,
            );
            let _ = interface.rml_ui().element_set_inner_rml(button, &markup);
        }
    }

    pub(super) fn render_dialog(&self, interface: &NativeInterfaceRef, document: u64) {
        let Some(dialog) = element_by_id(interface, document, "shading-texture-dialog") else {
            return;
        };
        let open = self.dialog.is_some();
        let _ = interface
            .rml_ui()
            .element_set_class(dialog, "hidden", !open);
        if let Some(name) = &self.dialog {
            if let Some(title) = element_by_id(interface, document, "shading-dialog-title") {
                let caption = SHADING_TOGGLES
                    .iter()
                    .find(|(_, shading, _)| shading == name)
                    .map(|(_, _, caption)| *caption)
                    .unwrap_or(name.as_str());
                let _ = interface
                    .rml_ui()
                    .element_set_inner_rml(title, &format!("{} texture", escape_rml(caption)));
            }
        }
        if let Some(choice) = element_by_id(interface, document, "shading-source-choice") {
            let _ = interface.rml_ui().element_set_class(
                choice,
                "hidden",
                !open || self.shading_source.is_some(),
            );
        }
        if let Some(new_form) = element_by_id(interface, document, "shading-new-form") {
            let _ = interface.rml_ui().element_set_class(
                new_form,
                "hidden",
                !open || self.shading_source != Some(ShadingSource::New),
            );
        }
        if let Some(existing) = element_by_id(interface, document, "shading-existing-grid") {
            let _ = interface.rml_ui().element_set_class(
                existing,
                "hidden",
                !open || self.shading_source != Some(ShadingSource::Existing),
            );
        }
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
