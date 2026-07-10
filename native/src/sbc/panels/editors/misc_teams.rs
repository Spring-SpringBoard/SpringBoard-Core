use spring_native::prelude::{Error, NativeInterfaceRef};

use crate::sbc::command_system::model::Models;
use crate::sbc::panels::editor::Editor;
use crate::sbc::panels::editor_base::{envelope_with, resolve_base, section_rml, FieldSet};
use crate::sbc::panels::field::{ChangeQueue, FieldValue, InteractionQueue};
use crate::sbc::panels::fields::{ColorField, NumericField, StringField};
use crate::sbc::panels::registry::{EditorSpec, Tab};
use crate::sbc::teams::{Color, Team, TeamManager};

// Mirrors the players/teams window in scen_edit/view/general/players_window.lua.
inventory::submit! {
    EditorSpec {
        name: "teamsView",
        tab: Tab::Misc,
        order: 1,
        caption: "Teams",
        tooltip: "Edit teams",
        image: "LuaUI/images/scenedit/person.png",
        make: || Box::new(TeamsView::new()),
    }
}

/// One row of fields per team. Field names carry the team id (`name_3`), which
/// `resolve_base` leaves alone, so the id is parsed back out on commit.
///
/// `UpdateTeamCommand` deserializes a whole `Team` and none of its fields have
/// defaults, so a partial payload is rejected. The loaded records are kept and
/// the edited field patched into a clone.
pub(crate) struct TeamsView {
    fields: FieldSet,
    teams: Vec<Team>,
}

/// `resolve_base` only strips colour sub-fields (`-r`/`-g`/`-b`/`-hex`), so a
/// team field name survives it intact and can be split here.
fn split_field(name: &str) -> Option<(&str, i32)> {
    let (base, id) = name.rsplit_once('_')?;
    Some((base, id.parse().ok()?))
}

fn team_field(base: &str, id: i32) -> String {
    format!("{base}_{id}")
}

impl TeamsView {
    pub(crate) fn new() -> Self {
        TeamsView {
            fields: FieldSet::new(Vec::new()),
            teams: Vec::new(),
        }
    }

    /// Rebuild the field set from the model. Teams are added and removed, so
    /// the fields cannot be fixed at construction like the Env views'.
    fn rebuild_fields(&mut self) {
        let mut fields: Vec<Box<dyn crate::sbc::panels::field::Field>> = Vec::new();
        for team in &self.teams {
            let id = team.id;
            fields.push(Box::new(StringField::new(
                &team_field("name", id),
                "Name",
                &team.name,
            )));
            fields.push(Box::new(ColorField::new(team_field("color", id), "Color")));
            fields.push(Box::new(
                NumericField::new(
                    team_field("allyTeam", id),
                    "Ally team",
                    team.ally_team as f32,
                )
                .min(0.0),
            ));
        }
        self.fields = FieldSet::new(fields);
    }

    /// Patch the edited values into the loaded record and send it whole.
    fn team_envelope(&self, id: i32, next: &mut u64) -> Vec<String> {
        let Some(team) = self.teams.iter().find(|t| t.id == id) else {
            return vec![];
        };
        let mut team = team.clone();
        team.name = self.fields.text(&team_field("name", id));
        if let FieldValue::Color(c) = self.fields.value(&team_field("color", id)) {
            team.color = Color {
                r: c[0],
                g: c[1],
                b: c[2],
            };
        }
        if let FieldValue::Number(n) = self.fields.value(&team_field("allyTeam", id)) {
            team.ally_team = n as i32;
        }
        let Ok(payload) = serde_json::to_value(&team) else {
            return vec![];
        };
        vec![envelope_with("UpdateTeamCommand", next, "team", payload)]
    }
}

impl Editor for TeamsView {
    fn generate_rml(&self) -> String {
        let mut h = String::new();
        for team in &self.teams {
            let id = team.id;
            h.push_str(&section_rml(&format!("Team {id}")));
            h.push_str(&self.fields.rml(&team_field("name", id)));
            h.push_str(&self.fields.rml(&team_field("color", id)));
            h.push_str(&self.fields.rml(&team_field("allyTeam", id)));
        }
        h
    }

    fn bind_fields(
        &mut self,
        interface: &NativeInterfaceRef,
        document: u64,
        changes: &ChangeQueue,
        interactions: &InteractionQueue,
    ) -> Result<(), Error> {
        self.fields.bind(interface, document, changes, interactions)
    }

    fn write_field_values(&self, interface: &NativeInterfaceRef) -> Result<(), Error> {
        self.fields.write_values(interface)
    }

    fn process_change(
        &mut self,
        name: &str,
        interface: &NativeInterfaceRef,
        next: &mut u64,
    ) -> Vec<String> {
        let base = resolve_base(name);
        self.fields.read(base, interface);
        match split_field(base) {
            Some((_, id)) => self.team_envelope(id, next),
            None => vec![],
        }
    }

    fn process_drag_end(&mut self, name: &str, next: &mut u64) -> Vec<String> {
        match split_field(resolve_base(name)) {
            Some((_, id)) => self.team_envelope(id, next),
            None => vec![],
        }
    }

    fn refresh_from_engine(&mut self, _interface: &NativeInterfaceRef, models: &mut Models) {
        let teams = models.get::<TeamManager>().all_teams();
        // Only rebuild the fields when the roster changed; otherwise the DOM is
        // rewritten under the user's cursor on every refresh.
        let roster_changed = teams
            .iter()
            .map(|t| t.id)
            .ne(self.teams.iter().map(|t| t.id));
        self.teams = teams;
        if roster_changed {
            self.rebuild_fields();
        }
        let teams = self.teams.clone();
        for team in &teams {
            let id = team.id;
            self.fields
                .set(&team_field("name", id), FieldValue::Text(team.name.clone()));
            self.fields.set(
                &team_field("color", id),
                FieldValue::Color([team.color.r, team.color.g, team.color.b, 1.0]),
            );
            self.fields.set(
                &team_field("allyTeam", id),
                FieldValue::Number(team.ally_team as f32),
            );
        }
    }

    fn drag_field(&mut self, name: &str, dx: f32, interface: &NativeInterfaceRef) -> bool {
        self.fields.drag(name, dx, interface)
    }

    fn drag_end_field(&mut self, name: &str, interface: &NativeInterfaceRef) -> bool {
        self.fields.drag_end(name, interface)
    }

    fn begin_edit_field(&mut self, name: &str, interface: &NativeInterfaceRef) {
        self.fields.begin_edit(name, interface)
    }

    fn cancel_edit_field(&mut self, name: &str, interface: &NativeInterfaceRef) {
        self.fields.cancel_edit(name, interface)
    }

    fn field_value(&self, name: &str) -> FieldValue {
        self.fields.value(name)
    }

    fn set_field_value(&mut self, name: &str, value: FieldValue, interface: &NativeInterfaceRef) {
        self.fields.set(resolve_base(name), value);
        let _ = self.fields.write_values(interface);
    }

    fn field_asset(&self, _name: &str) -> Option<(String, Vec<String>)> {
        None
    }
}
