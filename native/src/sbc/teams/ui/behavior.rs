use spring_native::prelude::{Error, NativeInterfaceRef};

use crate::sbc::command_system::command::Command;
use crate::sbc::command_system::model::Models;
use crate::sbc::panels::field::{element_by_id, ChangeQueue, FieldValue, InteractionQueue};
use crate::sbc::panels::runtime::{Behavior, EditorModel, Item, Outcome, Watch};
use crate::sbc::teams::commands::{AddTeamCommand, RemoveTeamCommand, UpdateTeamCommand};
use crate::sbc::teams::{Color as TeamColor, TeamManager};

use super::model::{extra_bool, TeamField, TeamsModel};

#[derive(Clone, Copy)]
pub(super) enum TeamClick {
    Add,
    Edit(i32),
    Remove(i32),
    Close,
}

impl TeamsModel {
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
        let team = team.clone();
        use TeamField::*;
        self.table.set(Name, FieldValue::Text(team.name.clone()));
        self.table
            .set(Ai, FieldValue::Bool(extra_bool(&team, "ai")));
        self.table.set(Metal, FieldValue::Number(team.metal));
        self.table.set(MetalMax, FieldValue::Number(team.metal_max));
        self.table.set(Energy, FieldValue::Number(team.energy));
        self.table
            .set(EnergyMax, FieldValue::Number(team.energy_max));
        self.table.set(
            Color,
            FieldValue::Color([team.color.r, team.color.g, team.color.b, 1.0]),
        );
        self.table.set(
            StartX,
            FieldValue::Number(super::model::extra_number(&team, "startPos", "x")),
        );
        self.table.set(
            StartZ,
            FieldValue::Number(super::model::extra_number(&team, "startPos", "z")),
        );
        self.table.set(Side, FieldValue::Text(team.side.0.clone()));
        self.editing = Some(id);
        for entry in self.table.fields() {
            let _ = entry.field.write_to_dom(interface);
        }
        self.show_dialog(interface, document);
    }

    fn finish_edit(
        &mut self,
        interface: &NativeInterfaceRef,
        document: u64,
    ) -> Option<Box<dyn Command>> {
        let id = self.editing.take()?;
        for entry in self.table.fields_mut() {
            let _ = entry.field.read_from_dom(interface);
        }
        self.show_dialog(interface, document);
        let mut team = self.teams.iter().find(|team| team.id == id)?.clone();
        use TeamField::*;
        team.name = self.text(Name);
        team.metal = self.number(Metal);
        team.metal_max = self.number(MetalMax);
        team.energy = self.number(Energy);
        team.energy_max = self.number(EnergyMax);
        team.side.0 = self.text(Side);
        if let FieldValue::Color(color) = self.table.value(Color) {
            team.color = TeamColor {
                r: color[0],
                g: color[1],
                b: color[2],
            };
        }
        team.extra
            .insert("ai".into(), serde_json::json!(self.boolean(Ai)));
        team.extra.insert(
            "startPos".into(),
            serde_json::json!({
                "x": self.number(StartX),
                "z": self.number(StartZ),
            }),
        );
        let payload = serde_json::to_value(team).ok()?;
        UpdateTeamCommand::from_team(payload).map(|c| Box::new(c) as Box<dyn Command>)
    }

    fn add_team(&self) -> Option<Box<dyn Command>> {
        let count = self
            .teams
            .iter()
            .filter(|team| !extra_bool(team, "gaia"))
            .count();
        let fields = serde_json::json!({
            "name": format!("New team: {count}"),
            "color": { "r": 0.35, "g": 0.65, "b": 0.95 },
            "allyTeam": 1,
            "side": "",
        });
        AddTeamCommand::from_fields(fields).map(|c| Box::new(c) as Box<dyn Command>)
    }
}

pub(crate) struct TeamsBehavior;

impl Behavior for TeamsBehavior {
    type Model = TeamsModel;

    /// The panel body is the team list; the edit dialog renders into the
    /// separate `team-edit-modal` host so it floats over the whole screen.
    fn layout(&self, model: &TeamsModel) -> Vec<Item<TeamField>> {
        vec![Item::Custom(model.list_rml())]
    }

    fn refresh(
        &mut self,
        model: &mut TeamsModel,
        engine: &NativeInterfaceRef,
        models: &mut Models,
    ) {
        if !model.fields_ready {
            model.build_fields(engine);
        }
        model.teams = models.get::<TeamManager>().all_teams();
        model.teams.sort_by_key(|team| team.id);
    }

    fn watch(&mut self, model: &mut TeamsModel, models: &mut Models) -> Watch {
        let teams = models.get::<TeamManager>().all_teams();
        model.roster_changed =
            serde_json::to_value(&teams).ok() != serde_json::to_value(&model.teams).ok();
        if model.roster_changed {
            Watch::Rebuild
        } else {
            Watch::Unchanged
        }
    }

    fn mount(
        &mut self,
        model: &mut TeamsModel,
        interface: &NativeInterfaceRef,
        document: u64,
    ) -> Result<(), Error> {
        if let Some(host) = element_by_id(interface, document, "team-edit-modal") {
            interface
                .rml_ui()
                .element_set_inner_rml(host, &model.dialog_rml())?;
        }
        Ok(())
    }

    fn bind(
        &mut self,
        model: &mut TeamsModel,
        interface: &NativeInterfaceRef,
        document: u64,
        _changes: &ChangeQueue,
        _interactions: &InteractionQueue,
    ) -> Result<(), Error> {
        let bind = |id: &str, click: TeamClick| -> Result<(), Error> {
            if let Some(button) = element_by_id(interface, document, id) {
                let clicks = model.clicks.clone();
                interface.rml_ui().element_add_event_listener(
                    button,
                    "click",
                    false,
                    move || {
                        clicks.borrow_mut().push(click);
                    },
                )?;
            }
            Ok(())
        };
        bind("teams-add", TeamClick::Add)?;
        bind("team-edit-close", TeamClick::Close)?;
        for team in &model.teams {
            if !extra_bool(team, "gaia") {
                bind(&format!("team-edit-{}", team.id), TeamClick::Edit(team.id))?;
                bind(
                    &format!("team-remove-{}", team.id),
                    TeamClick::Remove(team.id),
                )?;
            }
        }
        model.show_dialog(interface, document);
        Ok(())
    }

    fn tick(
        &mut self,
        model: &mut TeamsModel,
        interface: &NativeInterfaceRef,
        document: u64,
    ) -> Outcome {
        let clicks: Vec<_> = model.clicks.borrow_mut().drain(..).collect();
        let mut commands: Vec<Box<dyn Command>> = Vec::new();
        for click in clicks {
            match click {
                TeamClick::Add => {
                    if let Some(command) = model.add_team() {
                        commands.push(command);
                    }
                }
                TeamClick::Edit(id) => model.begin_edit(id, interface, document),
                TeamClick::Remove(id) => {
                    commands.push(Box::new(RemoveTeamCommand::new(id)));
                }
                TeamClick::Close => {
                    if let Some(command) = model.finish_edit(interface, document) {
                        commands.push(command);
                    }
                }
            }
        }
        Outcome::commands(commands)
    }

    fn modal_open(&self, model: &TeamsModel) -> bool {
        model.editing.is_some()
    }
}
