//! Runtime-backed completion catalogs for native Chonsole commands.

use std::collections::BTreeMap;

use spring_native::prelude::NativeInterfaceRef;
use spring_native::RulesParamValue;

use super::{ChonsoleCore, ConsoleCommand};

#[derive(Default)]
pub struct CatalogRefresher {
    metadata_loaded: bool,
}

impl CatalogRefresher {
    pub fn refresh(&mut self, interface: &NativeInterfaceRef, core: &mut ChonsoleCore) {
        self.refresh_engine(interface, core);
        self.refresh_rules(interface, core);
        if !self.metadata_loaded {
            self.refresh_static_metadata(interface, core);
            self.metadata_loaded = true;
        }
    }

    fn refresh_engine(&self, interface: &NativeInterfaceRef, core: &mut ChonsoleCore) {
        let gfx = interface.gfx();
        if let Ok(entries) = gfx.get_console_command_entries() {
            core.replace_catalog(
                entries
                    .into_iter()
                    .map(|entry| ConsoleCommand {
                        name: entry.command.to_ascii_lowercase(),
                        description: entry.description,
                        requires_cheat: entry.cheat,
                    })
                    .collect(),
            );
        }
        if let Ok(textures) = gfx.get_engine_texture_names() {
            core.set_textures(textures);
        }
    }

    fn refresh_rules(&self, interface: &NativeInterfaceRef, core: &mut ChonsoleCore) {
        let rules = interface.rules_params();
        let mut game_rules = rules
            .get_game_rules_params()
            .unwrap_or_default()
            .into_iter()
            .filter_map(|name| {
                let (value, _, exists) = rules.get_game_rules_param(&name).ok()?;
                exists.then(|| (name, rule_value_text(&value)))
            })
            .collect::<Vec<_>>();
        game_rules.sort_by(|left, right| left.0.cmp(&right.0));
        core.set_game_rules(game_rules);

        let teams = interface.teams().get_team_list(-1).unwrap_or_default();
        core.set_teams(teams.clone());
        let team_rules = teams
            .iter()
            .map(|team| {
                let mut values = rules
                    .get_team_rules_params(*team)
                    .unwrap_or_default()
                    .into_iter()
                    .filter_map(|name| {
                        let (value, _, exists) = rules.get_team_rules_param(*team, &name).ok()?;
                        exists.then(|| (name, rule_value_text(&value)))
                    })
                    .collect::<Vec<_>>();
                values.sort_by(|left, right| left.0.cmp(&right.0));
                (*team, values)
            })
            .collect::<BTreeMap<_, _>>();
        core.set_team_rules(team_rules);

        let selected_units = interface
            .selection()
            .get_selected_units()
            .unwrap_or_default();
        let mut unit_rules = BTreeMap::<String, Option<String>>::new();
        for (index, unit) in selected_units.iter().enumerate() {
            for name in rules.get_unit_rules_params(*unit).unwrap_or_default() {
                let Ok((value, _, true)) = rules.get_unit_rules_param(*unit, &name) else {
                    continue;
                };
                let value = rule_value_text(&value);
                match unit_rules.get_mut(&name) {
                    None if index == 0 => {
                        unit_rules.insert(name, Some(value));
                    }
                    Some(current) if current.as_ref() != Some(&value) => *current = None,
                    None => {
                        unit_rules.insert(name, None);
                    }
                    _ => {}
                }
            }
        }
        core.set_unit_rules(
            unit_rules
                .into_iter()
                .map(|(name, value)| (name, value.unwrap_or_else(|| "?".into())))
                .collect(),
        );
    }

    fn refresh_static_metadata(&self, interface: &NativeInterfaceRef, core: &mut ChonsoleCore) {
        let definitions = interface
            .unit_defs()
            .get_unit_def_ids()
            .unwrap_or_default()
            .into_iter()
            .filter_map(|id| {
                interface
                    .unit_defs()
                    .get_unit_def_basic_info(id)
                    .ok()
                    .flatten()
                    .map(|basic| {
                        let tooltip = (!basic.tooltip.is_empty())
                            .then_some(basic.tooltip)
                            .map(|tooltip| format!(". {tooltip}"))
                            .unwrap_or_default();
                        (basic.name, tooltip)
                    })
            })
            .filter(|(name, _)| !name.is_empty())
            .collect();
        core.set_unit_defs(definitions);

        let configs = interface
            .config()
            .get_config_parameters()
            .unwrap_or_default()
            .into_iter()
            .map(|param| {
                (
                    param.name,
                    param.description.unwrap_or_default().replace('\n', " "),
                )
            })
            .collect();
        core.set_config_params(configs);

        let players = interface
            .player()
            .get_player_roster_owned(0, false)
            .unwrap_or_default()
            .into_iter()
            .map(|entry| entry.name)
            .collect();
        core.set_players(players);
    }
}

fn rule_value_text(value: &RulesParamValue) -> String {
    match value {
        RulesParamValue::Bool(value) => value.to_string(),
        RulesParamValue::Float(value) => value.to_string(),
        RulesParamValue::String(value) => value.clone(),
    }
}
