use spring_native::prelude::{Error, NativeInterfaceRef};

use crate::sbc::panels::controls::grid::GridItem;
use crate::sbc::panels::editor_base::section_rml;
use crate::sbc::panels::runtime::Item;
use crate::sbc::rml::escape_rml;

use crate::sbc::textures::materials::list_materials;

use super::model::TexField::*;
use super::model::{material_tooltip, TexField, TextureUiModel, ADD_BRUSH_ID};

pub(super) fn layout(model: &TextureUiModel) -> Vec<Item<TexField>> {
    vec![
        Item::Custom(model.actions.generate_rml()),
        Item::Custom(section_markup_when(
            "texture-saved-brush-section",
            "Saved brushes",
            "texture_material_controls_visible",
        )),
        Item::Custom(format!(
            r#"<div id="texture-saved-brush-host" data-class-hidden="!texture_material_controls_visible">{}</div>"#,
            model.saved_brush_grid.container_rml(),
        )),
        Item::Custom(section_markup_when(
            "texture-pattern-section",
            "Pattern",
            "texture_material_controls_visible",
        )),
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
        Item::Custom(section_markup_when(
            "texture-splat-section",
            "Splat",
            "texture_dnts_controls_visible",
        )),
        Item::IdRow(&[SplatTexScale, SplatTexMult]),
        Item::IdField(DntsIndex),
        Item::IdField(Exclusive),
    ]
}

fn section_markup_when(id: &str, caption: &str, visible: &str) -> String {
    let plain = section_rml(caption);
    plain.replacen(
        r#"<div class="field-section">"#,
        &format!(
            r#"<div id="{}" class="field-section" data-class-hidden="!{}">"#,
            escape_rml(id),
            escape_rml(visible),
        ),
        1,
    )
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
            tooltip_content: None,
        }];
        for saved in &self.saved_brushes {
            let material = self.materials.iter().find(|m| m.name == saved.material);
            saved_items.push(GridItem {
                id: saved.id.clone(),
                caption: saved.material.clone(),
                image: material.and_then(|m| m.channels.get("diffuse").cloned()),
                is_directory: false,
                tooltip: material.map(|m| format!("Saved brush: {}", m.name)),
                tooltip_content: material.map(material_tooltip),
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
                tooltip_content: Some(material_tooltip(material)),
            })
            .collect();
        self.material_grid.set_items(items);
        self.material_grid
            .set_selected(self.selected_material.as_deref());
        self.material_grid.render(interface, document)
    }
}
