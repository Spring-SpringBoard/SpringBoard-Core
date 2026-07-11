use std::cell::RefCell;
use std::rc::Rc;

use spring_native::prelude::{Error, NativeInterfaceRef};

use crate::sbc::command_system::model::Models;
use crate::sbc::panels::editor::Editor;
use crate::sbc::envelope::envelope_fields;
use crate::sbc::panels::editor_base::{envelope_with, FieldSet, Layout};
use crate::sbc::panels::field::{element_by_id, escape_rml, ChangeQueue, FieldValue, InteractionQueue};
use crate::sbc::panels::fields::{BooleanField, ChoiceField, ColorField, NumericField, StringField};
use crate::sbc::panels::registry::{EditorSpec, Tab};
use crate::sbc::teams::{Color, Team, TeamManager};

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

#[derive(Clone, Copy)]
enum TeamClick {
    Add,
    Edit(i32),
    Remove(i32),
    Close,
}

pub(crate) struct TeamsView {
    fields: FieldSet,
    teams: Vec<Team>,
    editing: Option<i32>,
    roster_changed: bool,
    fields_ready: bool,
    clicks: Rc<RefCell<Vec<TeamClick>>>,
}

fn extra_bool(team: &Team, name: &str) -> bool {
    team.extra.get(name).and_then(serde_json::Value::as_bool).unwrap_or(false)
}

fn extra_number(team: &Team, object: &str, name: &str) -> f32 {
    team.extra
        .get(object)
        .and_then(serde_json::Value::as_object)
        .and_then(|value| value.get(name))
        .and_then(serde_json::Value::as_f64)
        .unwrap_or_default() as f32
}

fn prefix(team: &Team) -> &'static str {
    if extra_bool(team, "gaia") {
        "(Gaia)"
    } else if extra_bool(team, "ai") {
        "(AI)"
    } else {
        "(Player)"
    }
}

impl TeamsView {
    pub(crate) fn new() -> Self {
        TeamsView {
            fields: FieldSet::new(Vec::new()),
            teams: Vec::new(),
            editing: None,
            roster_changed: false,
            fields_ready: false,
            clicks: Rc::new(RefCell::new(Vec::new())),
        }
    }

    fn build_fields(&mut self, interface: &NativeInterfaceRef) {
        let count = interface.game().get_side_data_count().unwrap_or_default();
        let mut sides = Vec::new();
        for index in 0..count {
            let Ok(side) = interface.game().get_side_data_by_index(index) else {
                continue;
            };
            let name = unsafe {
                side.sideName
                    .as_ref()
                    .map(|ptr| std::ffi::CStr::from_ptr(ptr).to_string_lossy().into_owned())
                    .unwrap_or_default()
            };
            if !name.is_empty() {
                sides.push(name);
            }
        }
        // A project can carry a custom/legacy side even when the engine reports
        // no sides. Keep the control usable in that case.
        if sides.is_empty() {
            sides.push(String::new());
        }
        self.fields = FieldSet::new(vec![
            Box::new(StringField::new("teamName", "Name", "")),
            Box::new(BooleanField::new("teamAi", "AI", false)),
            Box::new(NumericField::new("teamMetal", "Metal", 0.0).min(0.0)),
            Box::new(NumericField::new("teamMetalMax", "Storage", 0.0).min(0.0)),
            Box::new(NumericField::new("teamEnergy", "Energy", 0.0).min(0.0)),
            Box::new(NumericField::new("teamEnergyMax", "Storage", 0.0).min(0.0)),
            Box::new(ColorField::new("teamColor", "Color")),
            Box::new(NumericField::new("teamStartX", "Start X", 0.0)),
            Box::new(NumericField::new("teamStartZ", "Start Z", 0.0)),
            Box::new(ChoiceField::new("teamSide", "Side", sides)),
        ]);
        self.fields_ready = true;
    }

    fn dialog_rml(&self) -> String {
        format!(
            concat!(
                r#"<div id="team-edit-dialog" class="picker-backdrop hidden">"#,
                r#"<div class="picker-dialog team-dialog"><div class="dialog-header"><span class="dialog-title">Edit team</span></div>"#,
                r#"<div class="dialog-content">{fields}</div>"#,
                r#"<div class="dialog-footer"><button id="team-edit-close" class="dialog-button primary">Close</button></div>"#,
                r#"</div></div>"#,
            ),
            fields = self.fields.generate_rml(&[
                Layout::Field("teamName"),
                Layout::Field("teamAi"),
                Layout::Group(&["teamMetal", "teamMetalMax"]),
                Layout::Section("Energy"),
                Layout::Group(&["teamEnergy", "teamEnergyMax"]),
                Layout::Field("teamColor"),
                Layout::Group(&["teamStartX", "teamStartZ"]),
                Layout::Field("teamSide"),
            ]),
        )
    }

    fn show_dialog(&self, interface: &NativeInterfaceRef, document: u64) {
        if let Some(dialog) = element_by_id(interface, document, "team-edit-dialog") {
            let _ = interface
                .rml_ui()
                .element_set_class(dialog, "hidden", self.editing.is_none());
        }
    }

    fn begin_edit(&mut self, id: i32, interface: &NativeInterfaceRef, document: u64) {
        let Some(team) = self.teams.iter().find(|team| team.id == id) else {
            return;
        };
        self.fields.set("teamName", FieldValue::Text(team.name.clone()));
        self.fields.set("teamAi", FieldValue::Bool(extra_bool(team, "ai")));
        self.fields.set("teamMetal", FieldValue::Number(team.metal));
        self.fields.set("teamMetalMax", FieldValue::Number(team.metal_max));
        self.fields.set("teamEnergy", FieldValue::Number(team.energy));
        self.fields.set("teamEnergyMax", FieldValue::Number(team.energy_max));
        self.fields.set(
            "teamColor",
            FieldValue::Color([team.color.r, team.color.g, team.color.b, 1.0]),
        );
        self.fields.set(
            "teamStartX",
            FieldValue::Number(extra_number(team, "startPos", "x")),
        );
        self.fields.set(
            "teamStartZ",
            FieldValue::Number(extra_number(team, "startPos", "z")),
        );
        self.fields.set("teamSide", FieldValue::Text(team.side.0.clone()));
        self.editing = Some(id);
        let _ = self.fields.write_values(interface);
        self.show_dialog(interface, document);
    }

    fn finish_edit(
        &mut self,
        interface: &NativeInterfaceRef,
        document: u64,
        next: &mut u64,
    ) -> Option<String> {
        let id = self.editing.take()?;
        for name in [
            "teamName", "teamAi", "teamMetal", "teamMetalMax", "teamEnergy",
            "teamEnergyMax", "teamStartX", "teamStartZ", "teamSide",
        ] {
            self.fields.read(name, interface);
        }
        self.show_dialog(interface, document);
        let mut team = self.teams.iter().find(|team| team.id == id)?.clone();
        team.name = self.fields.text("teamName");
        team.metal = self.fields.number("teamMetal");
        team.metal_max = self.fields.number("teamMetalMax");
        team.energy = self.fields.number("teamEnergy");
        team.energy_max = self.fields.number("teamEnergyMax");
        team.side.0 = self.fields.text("teamSide");
        if let FieldValue::Color(color) = self.fields.value("teamColor") {
            team.color = Color { r: color[0], g: color[1], b: color[2] };
        }
        team.extra.insert("ai".into(), serde_json::json!(self.fields.boolean("teamAi")));
        team.extra.insert(
            "startPos".into(),
            serde_json::json!({
                "x": self.fields.number("teamStartX"),
                "z": self.fields.number("teamStartZ"),
            }),
        );
        let payload = serde_json::to_value(team).ok()?;
        Some(envelope_with("UpdateTeamCommand", next, "team", payload))
    }

    fn add_team(&self, next: &mut u64) -> String {
        let count = self.teams.iter().filter(|team| !extra_bool(team, "gaia")).count();
        envelope_fields(
            "AddTeamCommand",
            next,
            serde_json::json!({
                "name": format!("New team: {count}"),
                "color": { "r": 0.35, "g": 0.65, "b": 0.95 },
                "allyTeam": 1,
                "side": "",
            }),
        )
    }
}

impl Editor for TeamsView {
    fn generate_rml(&self) -> String {
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
                    r#"<button id="team-edit-{id}" class="team-edit">Edit</button><button id="team-remove-{id}" class="team-remove">x</button>"#,
                    id = team.id,
                ));
            }
            html.push_str("</div>");
        }
        html
    }

    fn bind_fields(
        &mut self,
        interface: &NativeInterfaceRef,
        document: u64,
        changes: &ChangeQueue,
        interactions: &InteractionQueue,
    ) -> Result<(), Error> {
        if let Some(host) = element_by_id(interface, document, "team-edit-modal") {
            interface
                .rml_ui()
                .element_set_inner_rml(host, &self.dialog_rml())?;
        }
        self.fields.bind(interface, document, changes, interactions)?;
        let bind = |id: &str, click: TeamClick| -> Result<(), Error> {
            if let Some(button) = element_by_id(interface, document, id) {
                let clicks = self.clicks.clone();
                interface.rml_ui().element_add_event_listener(button, "click", false, move || {
                    clicks.borrow_mut().push(click);
                })?;
            }
            Ok(())
        };
        bind("teams-add", TeamClick::Add)?;
        bind("team-edit-close", TeamClick::Close)?;
        for team in &self.teams {
            if !extra_bool(team, "gaia") {
                bind(&format!("team-edit-{}", team.id), TeamClick::Edit(team.id))?;
                bind(&format!("team-remove-{}", team.id), TeamClick::Remove(team.id))?;
            }
        }
        self.show_dialog(interface, document);
        Ok(())
    }

    fn write_field_values(&self, interface: &NativeInterfaceRef) -> Result<(), Error> {
        self.fields.write_values(interface)
    }

    fn process_change(
        &mut self,
        name: &str,
        interface: &NativeInterfaceRef,
        _next: &mut u64,
    ) -> Vec<String> {
        self.fields.read(name, interface);
        vec![]
    }

    fn process_drag_end(&mut self, _name: &str, _next: &mut u64) -> Vec<String> {
        vec![]
    }

    fn tick(
        &mut self,
        interface: &NativeInterfaceRef,
        document: u64,
        next: &mut u64,
    ) -> Vec<String> {
        let clicks: Vec<_> = self.clicks.borrow_mut().drain(..).collect();
        let mut commands = Vec::new();
        for click in clicks {
            match click {
                TeamClick::Add => commands.push(self.add_team(next)),
                TeamClick::Edit(id) => self.begin_edit(id, interface, document),
                TeamClick::Remove(id) => commands.push(envelope_fields(
                    "RemoveTeamCommand",
                    next,
                    serde_json::json!({ "teamID": id }),
                )),
                TeamClick::Close => {
                    if let Some(command) = self.finish_edit(interface, document, next) {
                        commands.push(command);
                    }
                }
            }
        }
        commands
    }

    fn has_open_modal(&self) -> bool {
        self.editing.is_some()
    }

    fn wants_refresh(&mut self, models: &mut Models) -> bool {
        let teams = models.get::<TeamManager>().all_teams();
        self.roster_changed = serde_json::to_value(&teams).ok() != serde_json::to_value(&self.teams).ok();
        self.roster_changed
    }

    fn wants_rebuild(&self) -> bool {
        self.roster_changed
    }

    fn refresh_from_engine(&mut self, interface: &NativeInterfaceRef, models: &mut Models) {
        if !self.fields_ready {
            self.build_fields(interface);
        }
        self.teams = models.get::<TeamManager>().all_teams();
        self.teams.sort_by_key(|team| team.id);
    }

    crate::sb_field_editor_methods!();
}
