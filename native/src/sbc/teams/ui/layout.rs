use crate::sbc::panels::editor_base::{group_rml, section_rml};
use crate::sbc::panels::field::escape_rml;
use crate::sbc::panels::runtime::EditorModel;

use super::model::{extra_bool, prefix, TeamField, TeamsModel};

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
                r#"<div id="team-edit-dialog" class="picker-backdrop hidden">"#,
                r#"<div class="picker-dialog team-dialog"><div class="dialog-header"><span class="dialog-title">Edit team</span></div>"#,
                r#"<div class="dialog-content">{fields}</div>"#,
                r#"<div class="dialog-footer"><button id="team-edit-close" class="dialog-button primary">Close</button></div>"#,
                r#"</div></div>"#,
            ),
            fields = fields,
        )
    }

    pub(super) fn list_rml(&self) -> String {
        let mut html = String::from(
            r#"<div class="brush-actions"><button id="teams-add" class="brush-action"><img class="brush-action-image" src="LuaUI/images/scenedit/team-add.png"/><span class="brush-action-label">Add</span></button></div><div class="team-list-header">Teams</div>"#,
        );
        for team in &self.teams {
            let color = format!(
                "#{:02X}{:02X}{:02X}",
                (team.color.r.clamp(0.0, 1.0) * 255.0).round() as u8,
                (team.color.g.clamp(0.0, 1.0) * 255.0).round() as u8,
                (team.color.b.clamp(0.0, 1.0) * 255.0).round() as u8,
            );
            html.push_str(&format!(
                r#"<div class="team-row"><div class="team-swatch" style="background-color: {color};"></div><span class="team-name">{prefix} Team: {name}</span>"#,
                prefix = prefix(team),
                name = escape_rml(&team.name),
            ));
            if !extra_bool(team, "gaia") {
                html.push_str(&format!(
                    r#"<button id="team-edit-{id}" class="team-edit"><span>Edit</span></button><button id="team-remove-{id}" class="team-remove" title="Remove team"><img src="LuaUI/images/scenedit/cancel.png"/></button>"#,
                    id = team.id,
                ));
            }
            html.push_str("</div>");
        }
        html
    }
}
