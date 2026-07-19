use spring_native::prelude::{Error, NativeInterfaceRef};

use crate::sbc::panels::controls::grid::{GridItem, GridView};
use crate::sbc::panels::editor_base::section_rml;
use crate::sbc::panels::runtime::Item;
use crate::sbc::rml::{element_by_id, escape_rml};

use super::model::TexField::*;
use super::model::{
    enabled_name, list_materials, material_tooltip, toggle_channels, TexField, TextureUiModel,
    ADD_BRUSH_ID,
};

fn section_markup(id: &str, caption: &str) -> String {
    let plain = section_rml(caption);
    plain.replacen(
        r#"<div class="field-section">"#,
        &format!(r#"<div id="{}" class="field-section">"#, escape_rml(id)),
        1,
    )
}

pub(super) fn material_dialog_markup(material_grid: &GridView) -> String {
    format!(
        concat!(
            r#"<div id="texture-material-dialog" class="picker-backdrop hidden">"#,
            r#"<div class="dialog picker-dialog asset-dialog">"#,
            r#"<div class="dialog-header"><span class="dialog-title">Select material for new brush</span></div>"#,
            r#"<div class="dialog-content">{grid}</div>"#,
            r#"<div class="dialog-footer"><button id="texture-material-cancel" class="dialog-button">Cancel</button></div>"#,
            r#"</div></div>"#,
        ),
        grid = material_grid.container_rml(),
    )
}

pub(super) fn layout(model: &TextureUiModel) -> Vec<Item<TexField>> {
    vec![
        Item::Custom(model.actions.generate_rml()),
        Item::Custom(section_markup(
            "texture-saved-brush-section",
            "Saved brushes",
        )),
        Item::Custom(model.saved_brush_grid.container_rml()),
        Item::Custom(section_markup("texture-pattern-section", "Pattern")),
        Item::Grid(Pattern),
        Item::IdRow(&[Size, Rotation, TexScale]),
        // Texture-channel toggles are intentionally two balanced rows. Four
        // toggles in one row made their captions cramped in the 500dp panel.
        Item::IdRow(&[DiffuseEnabled, SpecularEnabled]),
        Item::IdRow(&[EmissionEnabled, ReflEnabled]),
        Item::IdRow(&[TexRotation, TexOffsetX, TexOffsetY]),
        Item::IdField(DiffuseColor),
        Item::IdField(Mode),
        Item::IdField(KernelMode),
        Item::Section("Blending"),
        Item::IdRow(&[Strength, FalloffFactor, FeatureFactor]),
        Item::IdField(Value),
        Item::IdField(VoidFactor),
        Item::Custom(section_markup("texture-splat-section", "Splat")),
        Item::IdRow(&[SplatTexScale, SplatTexMult]),
        Item::IdField(DntsIndex),
        Item::IdField(Exclusive),
    ]
}

impl TextureUiModel {
    pub(super) fn render_grids(
        &mut self,
        interface: &NativeInterfaceRef,
        document: u64,
    ) -> Result<(), Error> {
        if self.materials.is_empty() {
            self.materials = list_materials(interface);
        }

        let mut saved_items = vec![GridItem {
            id: ADD_BRUSH_ID.to_string(),
            caption: "Add".to_string(),
            image: Some("LuaUI/images/scenedit/plus.png".to_string()),
            is_directory: false,
            tooltip: Some("Add new saved brush".to_string()),
            tooltip_markup: None,
        }];
        for saved in &self.saved_brushes {
            let material = self.materials.iter().find(|m| m.name == saved.material);
            saved_items.push(GridItem {
                id: saved.id.clone(),
                caption: saved.material.clone(),
                image: material.and_then(|m| m.channels.get("diffuse").cloned()),
                is_directory: false,
                tooltip: material.map(|m| format!("Saved brush: {}", m.name)),
                tooltip_markup: material.map(material_tooltip),
            });
        }
        self.saved_brush_grid.set_items(saved_items);
        self.saved_brush_grid
            .set_selected(self.selected_brush.as_deref());
        self.saved_brush_grid.render(interface, document)?;

        // Show the diffuse, and say which channels the material actually ships --
        // Lua's material tooltip.
        let items: Vec<GridItem> = self
            .materials
            .iter()
            .map(|material| GridItem {
                id: material.name.clone(),
                caption: material.name.clone(),
                image: material.channels.get("diffuse").cloned(),
                is_directory: false,
                tooltip: None,
                tooltip_markup: Some(material_tooltip(material)),
            })
            .collect();
        self.material_grid.set_items(items);
        self.material_grid
            .set_selected(self.selected_material.as_deref());
        self.material_grid.render(interface, document)
    }

    /// Hide the fields the current mode does not use, as Lua does when each
    /// action button is pressed.
    pub(super) fn apply_visibility(&self, interface: &NativeInterfaceRef, document: u64) {
        let mode = self.paint_mode();

        let material = matches!(mode, "paint");
        let hidden: &[(&str, bool)] = &[
            ("mode", !material),
            ("texScale", !material),
            ("texRotation", !material),
            ("texOffsetX", !material),
            ("texOffsetY", !material),
            ("featureFactor", !material),
            ("diffuseColor", !material),
            ("kernelMode", mode != "blur"),
            ("splatTexScale", mode != "dnts"),
            ("splatTexMult", mode != "dnts"),
            ("value", mode != "dnts"),
            ("dntsIndex", mode != "dnts"),
            ("exclusive", mode != "dnts"),
            ("voidFactor", mode != "void"),
            ("strength", mode == "void"),
            ("falloffFactor", mode == "blur"),
        ];
        for (name, hide) in hidden {
            if let Some(elem) = element_by_id(interface, document, &format!("row-{name}")) {
                let _ = interface.rml_ui().element_set_class(elem, "hidden", *hide);
            }
        }
        for channel in toggle_channels() {
            if let Some(elem) = element_by_id(
                interface,
                document,
                &format!("row-{}", enabled_name(channel)),
            ) {
                let _ = interface
                    .rml_ui()
                    .element_set_class(elem, "hidden", !material);
            }
        }
        for (id, visible) in [
            ("texture-saved-brush-section", material),
            ("texture-saved-brush-grid", material),
            (
                "texture-material-dialog",
                material && self.material_picker_open,
            ),
            ("texture-splat-section", mode == "dnts"),
        ] {
            if let Some(elem) = element_by_id(interface, document, id) {
                let _ = interface
                    .rml_ui()
                    .element_set_class(elem, "hidden", !visible);
            }
        }
    }
}
