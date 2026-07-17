use std::any::Any;
use std::collections::HashMap;

use serde::{Deserialize, Serialize};
use serde_json::Value;
use spring_native::prelude::NativeInterfaceRef;
use spring_native::sys::TeamColor;

use crate::sbc::command_system::model::{Model, ModelFactory};
use crate::sbc::lua_bridge;

inventory::submit! { ModelFactory { make: |iface| Box::new(TeamManager::new(iface)) } }

/// A team's project data. Fields beyond color/resources (which we push to the
/// engine) round-trip verbatim via `extra`.
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(default)]
pub struct Team {
    pub id: i32,
    pub name: String,
    pub color: Color,
    #[serde(rename = "allyTeam")]
    pub ally_team: i32,
    pub side: TeamSide,
    pub metal: f32,
    #[serde(rename = "metalMax")]
    pub metal_max: f32,
    pub energy: f32,
    #[serde(rename = "energyMax")]
    pub energy_max: f32,
    /// Any remaining fields (gaia, ai, etc.) preserved as-is.
    #[serde(flatten)]
    pub extra: serde_json::Map<String, serde_json::Value>,
}

impl Default for Team {
    fn default() -> Self {
        Team {
            id: 0,
            name: String::new(),
            color: Color::default(),
            ally_team: 0,
            side: TeamSide::default(),
            metal: 0.0,
            metal_max: 0.0,
            energy: 0.0,
            energy_max: 0.0,
            extra: serde_json::Map::new(),
        }
    }
}

#[derive(Debug, Clone, Default, PartialEq, Eq, Serialize, Deserialize)]
#[serde(transparent)]
pub struct TeamSide(pub String);

#[derive(Debug, Clone, Copy, Default, Serialize, Deserialize)]
pub struct Color {
    pub r: f32,
    pub g: f32,
    pub b: f32,
}

/// Synced-side team model. 1:1 with `scen_edit/model/team_manager.lua`: keeps
/// the team table, allocates ids, pushes color/resources to the engine, and
/// notifies the synced Lua team model, whose listener mirrors changes to the
/// widget so the UI updates.
pub struct TeamManager {
    interface: NativeInterfaceRef,
    teams: HashMap<i32, Team>,
    team_id_count: i32,
}

impl Model for TeamManager {
    fn as_any_mut(&mut self) -> &mut dyn Any {
        self
    }
}

impl TeamManager {
    pub fn new(interface: NativeInterfaceRef) -> Self {
        let mut manager = TeamManager {
            interface,
            teams: HashMap::new(),
            team_id_count: 0,
        };
        manager.populate_from_engine();
        manager
    }

    /// Add a team. If `team_id` is `None`, allocate the next id. Returns the id.
    pub fn add_team(&mut self, mut team: Team, team_id: Option<i32>) -> i32 {
        let id = team_id.unwrap_or(self.team_id_count + 1);
        team.id = id;
        if id > self.team_id_count {
            self.team_id_count = id;
        }
        self.teams.insert(id, team.clone());
        self.apply_team_to_engine(id, &team);
        self.notify_add_team(id, &team);
        id
    }

    pub fn remove_team(&mut self, team_id: i32) {
        if self.teams.remove(&team_id).is_some() {
            self.notify_remove_team(team_id);
        }
    }

    pub fn set_team(&mut self, team_id: i32, team: Team) {
        if !self.teams.contains_key(&team_id) {
            return;
        }
        self.teams.insert(team_id, team.clone());

        self.apply_team_to_engine(team_id, &team);

        self.notify_update_team(team_id, &team);
    }

    pub fn get_team(&self, team_id: i32) -> Option<&Team> {
        self.teams.get(&team_id)
    }

    pub fn all_teams(&self) -> Vec<Team> {
        let mut ids: Vec<i32> = self.teams.keys().copied().collect();
        ids.sort();
        ids.into_iter()
            .filter_map(|id| self.teams.get(&id).cloned())
            .collect()
    }

    pub fn clear(&mut self) {
        for team in self.all_teams() {
            self.remove_team(team.id);
        }
        self.team_id_count = 0;
    }

    /// Replace the model with the engine's current teams.
    pub fn populate_from_engine(&mut self) {
        self.clear();

        let gaia_id = self.interface.game().get_gaia_team_id().unwrap_or(-1);
        // -1 asks the engine for every team (mirrors Lua `Spring.GetTeamList()`).
        let mut ids = self.interface.teams().get_team_list(-1).unwrap_or_default();
        ids.sort_unstable();
        ids.dedup();

        for id in ids {
            let team = self.read_engine_team(id, gaia_id);
            self.add_team(team, Some(id));
        }
    }

    /// The most recently allocated team id (`0` before any team exists).
    pub fn latest_id(&self) -> i32 {
        self.team_id_count
    }

    fn read_engine_team(&self, id: i32, gaia_id: i32) -> Team {
        let teams = self.interface.teams();
        let ally_team = teams.get_team_ally_team_id(id).unwrap_or(0);
        let side = teams
            .get_team_info_owned(id, false)
            .map(|info| info.side)
            .unwrap_or_default();
        let color = self
            .interface
            .display()
            .get_team_color(id)
            .map(|c| Color {
                r: c.r,
                g: c.g,
                b: c.b,
            })
            .unwrap_or_default();
        let (metal, metal_max) = teams
            .get_team_resources(id, "metal")
            .map(|r| (r.metalCurrent, r.metalStorage))
            .unwrap_or((0.0, 0.0));
        let (energy, energy_max) = teams
            .get_team_resources(id, "energy")
            .map(|r| (r.energyCurrent, r.energyStorage))
            .unwrap_or((0.0, 0.0));

        let mut extra = serde_json::Map::new();
        if id == gaia_id {
            extra.insert("gaia".to_string(), Value::Bool(true));
            extra.insert("ai".to_string(), Value::Bool(true));
        }

        Team {
            id,
            name: id.to_string(),
            color,
            ally_team,
            side: TeamSide(side),
            metal,
            metal_max,
            energy,
            energy_max,
            extra,
        }
    }

    fn apply_team_to_engine(&self, team_id: i32, team: &Team) {
        let c = team.color;
        let _ = self.interface.display().set_team_color(
            team_id,
            TeamColor {
                r: c.r,
                g: c.g,
                b: c.b,
                a: 1.0,
            },
        );
        self.set_team_resources(team_id, team);
    }

    fn set_team_resources(&self, team_id: i32, team: &Team) {
        let ctrl = self.interface.synced_ctrl();
        let team_ctrl = ctrl.team();
        let _ = team_ctrl.set_team_resource(team_id, "m", team.metal);
        let _ = team_ctrl.set_team_resource(team_id, "ms", team.metal_max);
        let _ = team_ctrl.set_team_resource(team_id, "e", team.energy);
        let _ = team_ctrl.set_team_resource(team_id, "es", team.energy_max);
    }

    // Notify the synced Lua team model; its gadget listener mirrors the change
    // on to the widget. Sending to the widget here too would double-apply it
    // (and warn on a remove of an already-gone team).
    fn notify_add_team(&self, team_id: i32, team: &Team) {
        lua_bridge::rules_command(
            &self.interface,
            serde_json::json!({
                "className": "WidgetAddTeamCommand",
                "id": team_id,
                "value": team,
            }),
        );
    }

    fn notify_remove_team(&self, team_id: i32) {
        lua_bridge::rules_command(
            &self.interface,
            serde_json::json!({
                "className": "WidgetRemoveTeamCommand",
                "id": team_id,
            }),
        );
    }

    fn notify_update_team(&self, team_id: i32, team: &Team) {
        lua_bridge::rules_command(
            &self.interface,
            serde_json::json!({
                "className": "WidgetUpdateTeamCommand",
                "teamID": team_id,
                "team": team,
            }),
        );
    }
}
