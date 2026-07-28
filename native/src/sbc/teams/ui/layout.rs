use crate::sbc::panels::editor_base::{group_rml, section_rml};
use crate::sbc::panels::runtime::EditorModel;

use super::model::{TeamField, TeamsModel};

pub(super) const TEAM_LIST_RML: &str = concat!(
    r#"<div class="brush-actions"><button id="teams-add" class="brush-action"><img class="brush-action-image" src="LuaUI/images/scenedit/team-add.png"/><span class="brush-action-label">Add</span></button></div>"#,
    r#"<div class="team-list-header">Teams</div>"#,
    r#"<div id="teams-list"><div data-for="team : teams" data-if="team.visible" class="team-row"><div class="team-swatch" data-style-background-color="team.colour"></div><span class="team-name">{{ team.label }}</span><button class="team-edit" data-if="team.actions_enabled"><span>Edit</span></button><button class="team-remove" title="Remove team" data-if="team.actions_enabled"><img src="LuaUI/images/scenedit/cancel.png"/></button></div></div>"#,
);

impl TeamsModel {
    pub(super) fn dialog_rml(&self) -> String {
        let field = |id| {
            self.table
                .fields()
                .into_iter()
                .find(|entry| self.table.id_of(entry.field.name()) == Some(id))
                .map(|entry| entry.field.generate_rml())
                .unwrap_or_default()
        };
        use TeamField::*;
        let mut fields = String::new();
        fields.push_str(&field(Name));
        fields.push_str(&field(Ai));
        fields.push_str(&group_rml(&[field(Metal), field(MetalMax)]));
        fields.push_str(&section_rml("Energy"));
        fields.push_str(&group_rml(&[field(Energy), field(EnergyMax)]));
        fields.push_str(&field(Color));
        fields.push_str(&group_rml(&[field(StartX), field(StartZ)]));
        fields.push_str(&field(Side));
        format!(
            concat!(
                r#"<div id="team-edit-dialog" class="picker-backdrop" data-model="editor_fields" data-class-hidden="!team_dialog_open">"#,
                r#"<div class="picker-dialog team-dialog"><div class="dialog-header"><span class="dialog-title">Edit team</span></div>"#,
                r#"<div class="dialog-content">{fields}</div>"#,
                r#"<div class="dialog-footer"><button id="team-edit-close" class="dialog-button primary">Close</button></div>"#,
                r#"</div></div>"#,
            ),
            fields = fields,
        )
    }
}
