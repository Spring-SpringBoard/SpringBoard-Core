use std::cell::RefCell;
use std::rc::Rc;

use spring_native::{
    prelude::{Error, NativeInterfaceRef},
    RmlColor, RmlDataModel, RmlDataSwatchRows, RmlSwatchRow,
};

use crate::sbc::panels::field::FieldValue;
use crate::sbc::panels::fields::{
    BooleanField, ChoiceField, ColorField, NumericField, StringField,
};
use crate::sbc::panels::runtime::{EditorModel, FieldMut, FieldRef, TableEntry, TableModel};
use crate::sbc::teams::Team;

use super::behavior::TeamClick;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub(crate) enum TeamField {
    Name,
    Ai,
    Metal,
    MetalMax,
    Energy,
    EnergyMax,
    Color,
    StartX,
    StartZ,
    Side,
}

pub(super) fn extra_bool(team: &Team, name: &str) -> bool {
    team.extra
        .get(name)
        .and_then(serde_json::Value::as_bool)
        .unwrap_or(false)
}

pub(super) fn extra_number(team: &Team, object: &str, name: &str) -> f32 {
    team.extra
        .get(object)
        .and_then(serde_json::Value::as_object)
        .and_then(|value| value.get(name))
        .and_then(serde_json::Value::as_f64)
        .unwrap_or_default() as f32
}

pub(super) fn prefix(team: &Team) -> &'static str {
    if extra_bool(team, "gaia") {
        "(Gaia)"
    } else if extra_bool(team, "ai") {
        "(AI)"
    } else {
        "(Player)"
    }
}

pub(crate) struct TeamsModel {
    pub(super) table: TableModel<TeamField>,
    pub(super) teams: Vec<Team>,
    pub(super) editing: Option<i32>,
    pub(super) roster_changed: bool,
    pub(super) fields_ready: bool,
    pub(super) clicks: Rc<RefCell<Vec<TeamClick>>>,
    team_rows: Option<RmlDataSwatchRows<'static>>,
    pub(super) team_dialog_open: Option<spring_native::RmlDataVariable<'static, bool>>,
}

impl TeamsModel {
    pub(crate) fn new() -> Self {
        TeamsModel {
            table: TableModel::new(Vec::new()),
            teams: Vec::new(),
            editing: None,
            roster_changed: false,
            fields_ready: false,
            clicks: Rc::new(RefCell::new(Vec::new())),
            team_rows: None,
            team_dialog_open: None,
        }
    }

    pub(super) fn build_fields(&mut self, interface: &NativeInterfaceRef) {
        let count = interface.game().get_side_data_count().unwrap_or_default();
        let mut sides = Vec::new();
        for index in 0..count {
            let Ok(side) = interface.game().get_side_data_by_index_owned(index) else {
                continue;
            };
            let name = side.name;
            if !name.is_empty() {
                sides.push(name);
            }
        }
        // A project can carry a custom/legacy side even when the engine reports
        // no sides. Keep the control usable in that case.
        if sides.is_empty() {
            sides.push(String::new());
        }
        use TeamField::*;
        self.table = TableModel::new(vec![
            TableEntry::new(Name, Box::new(StringField::new("teamName", "Name", ""))),
            TableEntry::new(Ai, Box::new(BooleanField::new("teamAi", "AI", false))),
            TableEntry::new(
                Metal,
                Box::new(NumericField::new("teamMetal", "Metal", 0.0).min(0.0)),
            ),
            TableEntry::new(
                MetalMax,
                Box::new(NumericField::new("teamMetalMax", "Storage", 0.0).min(0.0)),
            ),
            TableEntry::new(
                Energy,
                Box::new(NumericField::new("teamEnergy", "Energy", 0.0).min(0.0)),
            ),
            TableEntry::new(
                EnergyMax,
                Box::new(NumericField::new("teamEnergyMax", "Storage", 0.0).min(0.0)),
            ),
            TableEntry::new(Color, Box::new(ColorField::new("teamColor", "Color"))),
            TableEntry::new(
                StartX,
                Box::new(NumericField::new("teamStartX", "Start X", 0.0)),
            ),
            TableEntry::new(
                StartZ,
                Box::new(NumericField::new("teamStartZ", "Start Z", 0.0)),
            ),
            TableEntry::new(Side, Box::new(ChoiceField::new("teamSide", "Side", sides))),
        ]);
        self.fields_ready = true;
    }

    pub(super) fn number(&self, id: TeamField) -> f32 {
        match self.table.value(id) {
            FieldValue::Number(n) => n,
            _ => 0.0,
        }
    }

    pub(super) fn text(&self, id: TeamField) -> String {
        match self.table.value(id) {
            FieldValue::Text(t) => t,
            _ => String::new(),
        }
    }

    pub(super) fn boolean(&self, id: TeamField) -> bool {
        matches!(self.table.value(id), FieldValue::Bool(true))
    }

    pub(super) fn write_team_rows(&self) -> Result<(), Error> {
        let Some(rows) = &self.team_rows else {
            return Ok(());
        };
        rows.set(
            &self
                .teams
                .iter()
                .map(|team| RmlSwatchRow {
                    label: format!("{} Team: {}", prefix(team), team.name),
                    color: RmlColor {
                        red: (team.color.r.clamp(0.0, 1.0) * 255.0).round() as u8,
                        green: (team.color.g.clamp(0.0, 1.0) * 255.0).round() as u8,
                        blue: (team.color.b.clamp(0.0, 1.0) * 255.0).round() as u8,
                        alpha: u8::MAX,
                    },
                    actions_enabled: !extra_bool(team, "gaia"),
                })
                .collect::<Vec<_>>(),
        )
    }
}

impl EditorModel for TeamsModel {
    type Id = TeamField;

    fn fields(&self) -> Vec<FieldRef<'_>> {
        self.table.fields()
    }

    fn fields_mut(&mut self) -> Vec<FieldMut<'_>> {
        self.table.fields_mut()
    }

    fn prepare_data_model(&mut self, model: &RmlDataModel<'static>) -> Result<(), Error> {
        self.team_rows = Some(model.bind_swatch_rows("teams")?);
        self.team_dialog_open = Some(model.bind("team_dialog_open", false)?);
        self.write_team_rows()
    }

    fn id_of(&self, name: &str) -> Option<TeamField> {
        self.table.id_of(name)
    }

    fn name_of(&self, id: TeamField) -> String {
        self.table.name_of(id)
    }
}
