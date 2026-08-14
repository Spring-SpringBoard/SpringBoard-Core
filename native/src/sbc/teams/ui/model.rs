use std::cell::RefCell;
use std::rc::Rc;

use spring_native::{
    prelude::{Error, NativeInterfaceRef},
    RmlColor, RmlDataModel, RmlFieldType, RmlValueRef,
};

use crate::sbc::rml::rows::{Row, Rows};

use crate::sbc::panels::field::FieldValue;
use crate::sbc::panels::fields::{
    BooleanField, ChoiceField, ColorField, NumericField, StringField,
};
use crate::sbc::panels::runtime::{EditorModel, FieldMut, FieldRef, TableEntry, TableModel};
use crate::sbc::teams::Team;

use super::behavior::TeamClick;

pub(crate) struct SwatchRow {
    pub label: String,
    pub color: RmlColor,
    pub actions_enabled: bool,
}

impl Row for SwatchRow {
    const FIELDS: &'static [(&'static str, RmlFieldType)] = &[
        ("label", RmlFieldType::String),
        ("colour", RmlFieldType::Color),
        ("actions_enabled", RmlFieldType::Bool),
    ];

    fn values<'a>(&'a self, out: &mut Vec<RmlValueRef<'a>>) {
        out.push(RmlValueRef::String(&self.label));
        out.push(RmlValueRef::Color(self.color));
        out.push(RmlValueRef::Bool(self.actions_enabled));
    }
}

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

fn team_table(sides: Vec<String>) -> TableModel<TeamField> {
    use TeamField::*;
    TableModel::new(vec![
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
    ])
}

pub(crate) struct TeamsModel {
    pub(super) table: TableModel<TeamField>,
    pub(super) teams: Vec<Team>,
    pub(super) editing: Option<i32>,
    pub(super) roster_changed: bool,
    pub(super) fields_ready: bool,
    pub(super) clicks: Rc<RefCell<Vec<TeamClick>>>,
    /// Team id by row index, so the row event handlers resolve a click without
    /// borrowing the roster. Refreshed whenever the rows are written.
    row_team_ids: Rc<RefCell<Vec<i32>>>,
    team_rows: Option<Rows<SwatchRow>>,
    pub(super) team_dialog_open: Option<spring_native::RmlDataVariable<'static, bool>>,
}

impl TeamsModel {
    pub(crate) fn new() -> Self {
        TeamsModel {
            // Declared up front, without the engine: the control channel
            // describes an editor by building one, and a model that only grows
            // its fields once the engine is up would describe none.
            table: team_table(vec![String::new()]),
            teams: Vec::new(),
            editing: None,
            roster_changed: false,
            fields_ready: false,
            clicks: Rc::new(RefCell::new(Vec::new())),
            row_team_ids: Rc::new(RefCell::new(Vec::new())),
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
        self.table = team_table(sides);
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
        *self.row_team_ids.borrow_mut() = self.teams.iter().map(|team| team.id).collect();
        rows.set(
            &self
                .teams
                .iter()
                .map(|team| SwatchRow {
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
        self.team_rows = Some(Rows::<SwatchRow>::bind(model, "teams")?);
        self.team_dialog_open = Some(model.bind("team_dialog_open", false)?);

        for (name, click) in [
            ("edit_team", TeamClick::Edit as fn(i32) -> TeamClick),
            ("remove_team", TeamClick::Remove as fn(i32) -> TeamClick),
        ] {
            let ids = self.row_team_ids.clone();
            let queue = self.clicks.clone();
            Rows::<SwatchRow>::on_row(model, name, move |index, _| {
                if let Some(id) = ids.borrow().get(index) {
                    queue.borrow_mut().push(click(*id));
                }
            })?;
        }
        self.write_team_rows()
    }

    fn id_of(&self, name: &str) -> Option<TeamField> {
        self.table.id_of(name)
    }

    fn name_of(&self, id: TeamField) -> String {
        self.table.name_of(id)
    }
}
